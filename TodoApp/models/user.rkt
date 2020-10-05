#lang racket

(require "../axio/axio.rkt")

(require db)

(provide build-user
         create-user
         delete-user
         user-from-attributes
         get-users
         is-admin?
         login-user
         read-user
         read-user-by-username
         update-user
         username-available?
         (struct-out user))

(struct user (id
              created-at
              email
              is-admin
              password-hash
              password-salt
              username)
        #:transparent)

(define select-columns
  ;0   1           2              3              4         5      6
  "id, created_at, password_hash, password_salt, username, email, is_admin")

;; --------------------------------------------------------------------------------------------
;; Public Interface
;; --------------------------------------------------------------------------------------------

(define (build-user username password-hash password-salt
                    #:created-at [ created-at #f ]
                    #:email      [ email      #f ]
                    #:id         [ id         #f ]
                    #:is-admin   [ is-admin   #f ]
                    )
  (user id
        created-at
        email
        is-admin
        password-hash
        password-salt
        username))

(define/contract (create-user conn obj)
  (-> connection? user? integer?)

  (query-value conn
               (string-append
                "insert into app_user"
                " (username, email, password_hash, password_salt, is_admin) "
                "values"
                " ($1, $2, $3, $4, $5) "
                "returning id")
               (user-username obj)
               (or (user-email obj) sql-null)
               (user-password-hash obj)
               (user-password-salt obj)
               (is-admin? obj)))

(define/contract (delete-user conn id)
  (-> connection? integer? any)
  (query-exec conn "delete from app_user where id = $1" id))

(define (user-from-attributes attrs obj #:accessor [ accessor (λ (o k) (hash-ref o k #f)) ])
  (define-values (password-hash password-salt)
    (let* ([ salt (if obj
                      (user-password-salt obj)
                      (random-string 20)) ]
           [ pswd-attr (accessor attrs "password") ]
           [ pswd-hash (cond [ (non-empty-string? pswd-attr) (hash-password pswd-attr salt) ]
                             [ obj                           (user-password-hash obj)       ]
                             [ else (raise "user-from-attributes: missing password")        ]) ])
      (values pswd-hash salt)))

  (build-user (accessor attrs "username")
              password-hash
              password-salt
              #:id       (if obj (user-id obj) #f )
              #:email    (accessor attrs "email")
              #:is-admin (equal? "true" (accessor attrs "is-admin"))))

(define/contract (get-users conn)
  (-> connection? list?)

  (define rows (query-rows conn
                           (string-append
                            "select " select-columns " "
                            "from app_user "
                            "order by username asc")))

  (map make-user rows))

(define/contract (is-admin? user)
  (-> user? boolean?)
  (and user (user-is-admin user)))

;; If password is valid for user, return user struct; otherwise, return #f
(define/contract (login-user conn username password)
  (-> connection? string? string? (or/c user? #f))
  (let ([ user (read-user-by-username conn username) ])
    (if user
        (let ([ uname         (user-username user)      ]
              [ password-hash (user-password-hash user) ]
              [ password-salt (user-password-salt user) ])
          (if (and (equal? (string-downcase uname) (string-downcase username))
                   (equal? password-hash (hash-password password password-salt)))
              user
              #f))
        #f)))

(define/contract (read-user conn id)
  (-> connection? integer? (or/c user? #f))
  (let ([ row (query-maybe-row conn
                               (string-append
                                "select " select-columns " "
                                "from app_user "
                                "where id = $1")
                               id) ])
    (if row
        (make-user row)
        #f)))

(define/contract (read-user-by-username conn username)
  (-> connection? string? (or/c user? #f))
  (let ([ row (query-maybe-row conn
                               (string-append
                                "select " select-columns " "
                                "from app_user "
                                "where lower(username) = $1")
                               (string-downcase username)) ])
    (if row
        (make-user row)
        #f)))

(define/contract (update-user conn obj)
  (-> connection? user? any)
  (query-exec conn
              (string-append
               "update app_user "
               "set username=$2, email=$3, password_hash=$4, password_salt=$5, is_admin=$6 "
               "where id=$1")
              (user-id obj)
              (user-username obj)
              (or (user-email obj) sql-null)
              (user-password-hash obj)
              (user-password-salt obj)
              (is-admin? obj)))

(define/contract (username-available? conn existing-id username)
  (-> connection? exact-nonnegative-integer? string? boolean?)
  (query-value conn
               (string-append
                "select not exists ("
                "select 1 from app_user "
                "where id != $1 and username = $2"
                ")")
               existing-id
               username))

;; --------------------------------------------------------------------------------------------
;; Private Implementation
;; --------------------------------------------------------------------------------------------

(define (make-user row)
  (let ([ is-admin  (vector-ref row 6) ])
    (build-user (vector-ref row 4) ; username
                (vector-ref row 2) ; password-hash
                (vector-ref row 3) ; password-salt
                #:created-at (sql-timestamp->moment (vector-ref row 1))
                #:email      (vector-ref row 5)
                #:id         (vector-ref row 0)
                #:is-admin   (if (sql-null? is-admin) #f is-admin))))

;; ---------------------------------------------------------------------------------------------
;; Tests
;; ---------------------------------------------------------------------------------------------

(module+ test
  (require rackunit)

  (define axio-ctx (axio-init 'test))

  (define (open-db)
    (define connection (axio-context-db-conn axio-ctx))
    connection)

  (define (exec-db-test proc)
    (define conn (open-db))
    (dynamic-wind void
                  (λ () (proc conn))
                  (λ ()
                    ;; virtual connection
                    (void))))

  (define sample-email1   "foo@bar.com")
  (define sample-email2   "fred@flintstone.com")

  (define sample-username "userfred")
  (define sample-user-pswd "sesame")
  (define sample-user-salt "et36db58gj25svt97mg85bft2")

  (define (create-sample-user conn)
    (let ([ user (build-user sample-username
                             (hash-password sample-user-pswd sample-user-salt)
                             sample-user-salt) ])
      (create-user conn user)))

  ;; ------------------------------------------------------------------------------------------
  ;; CRUD
  ;; ------------------------------------------------------------------------------------------

  (exec-db-test
   (λ (conn)

     ; Create a record
     (let* ([ user-id  (create-sample-user conn) ]
            [ user-obj (read-user conn user-id)  ])
       (check-false (is-admin? user-obj))
       (check-equal? (user-username user-obj) sample-username)
       (check-equal? (user-password-salt user-obj) sample-user-salt)
       (check-equal? (user-password-hash user-obj)
                     (hash-password sample-user-pswd sample-user-salt))

       (let ([ updated-user (struct-copy user user-obj
                                         [ password-hash "XYZ" ]) ])
         ; Update a record
         (update-user conn updated-user))

       (let ([ updated-user (read-user conn user-id) ])
         ; Verify updated
         (check-equal? (user-password-hash updated-user) "XYZ"))

       ; Delete records
       (delete-user conn user-id)

       ; Verify deleted
       (check-false (read-user conn user-id)))

     ))
  )

;; ---------------------------------------------------------------------------------------------
;; Setup
;; ---------------------------------------------------------------------------------------------

(module+ main
  (define axio-ctx (axio-init 'production))
  (define conn     (axio-context-db-conn axio-ctx))

  ;; Create user
  (let* ([ salt (random-string 20) ]
         [ pswd "rcon10"           ]
         [ user (build-user "admin"
                            (hash-password pswd salt)
                            salt
                            #:email    "admin@example.com"
                            #:is-admin #t) ])

    (create-user conn user)))
