#lang racket

(require "../axio/axio.rkt"
         "./comment.rkt"
         "./user.rkt")

(require csv-writing
         db
         gregor
         racket/generator)

(provide build-todo
         create-todo
         default-priority
         delete-todo
         format-priority
         todo-from-attributes
         get-todos+users
         is-completed?
         read-todo
         todo-generator
         todo-priorities
         update-todo
         (struct-out todo))

(struct todo (id
              user-id
              user-obj
              comments
              created-at
              completed-at
              title
              description
              priority)
        #:transparent)

(define default-priority 2) ; 1=high, 2=normal, 3=low

(define todo-priorities '(1 2 3))

(define (format-priority p)
  (match p
    [ 1 "High" ]
    [ 2 "Normal" ]
    [ 3 "Low" ]))

(define select-columns
  (string-append
   ;;    0        1             2                3
   "todo.id, todo.user_id, todo.created_at, todo.completed_at,"
   ;;     4           5                 6
   " todo.title, todo.description, todo.priority"))

;; --------------------------------------------------------------------------------------------
;; Public Interface
;; --------------------------------------------------------------------------------------------

(define (build-todo user-id title description
                    #:comments     [ comments     #f                ]
                    #:completed-at [ completed-at #f                ]
                    #:created-at   [ created-at   #f                ]
                    #:id           [ id           #f                ]
                    #:priority     [ priority     default-priority  ]
                    #:user         [ user-obj     #f                ])
  (todo id
        user-id
        user-obj
        comments
        created-at
        completed-at
        title
        description
        priority))

(define/contract (create-todo conn obj)
  (-> connection? todo? integer?)

  (query-value conn
               (string-append
                "insert into todo"
                " (user_id, completed_at, description, title, priority) "
                "values"
                " ($1, $2, $3, $4, $5) "
                "returning id")
               (todo-user-id obj)
               (db-write-timestamptz (todo-completed-at obj))
               (or (todo-description obj) sql-null)
               (or (todo-title obj) sql-null)
               (todo-priority obj)))

(define/contract (delete-todo conn id)
  (-> connection? integer? any)
  (query-exec conn "delete from todo where id = $1" id))

(define (todo-from-attributes user-id attrs obj #:accessor [ accessor (λ (o k) (hash-ref o k #f)) ])
  (define (is-attr-completed?)
    (let ([ completed (accessor attrs "completed") ])
      (and completed (equal? completed "true"))))

  (define (is-obj-completed?)
    (and obj (is-completed? obj)))

  (define (completed-at)
    (let ([ attr-completed (is-attr-completed?) ]
          [ obj-completed  (is-obj-completed?)  ])
      (if obj-completed
          (if attr-completed
              (todo-completed-at obj) ; Keep existing timestamp
              #f)                     ; Reset to uncompleted
          (if attr-completed
              (now/moment)            ; Mark completed as of now
              #f))))                  ; Keep as uncompleted

    (build-todo user-id
                (accessor attrs "title")
                (accessor attrs "description")
                #:id (accessor attrs "id")
                #:completed-at (completed-at)
                #:priority (string->number (accessor attrs "priority"))))

(define/contract (todo-generator conn)
  (-> connection? generator?)
  (define (create-row obj)
    (let ([ id           (todo-id obj)                       ]
          [ username     (user-username (todo-user-obj obj)) ]
          [ completed-at (if (todo-completed-at obj)
                             (~t (todo-completed-at obj)
                                 "MM/dd/yyyy HH:mm:ss")
                             "")                             ]
          [ created-at   (~t (todo-created-at obj)
                             "MM/dd/yyyy HH:mm:ss")          ]
          [ description  (todo-description obj)              ]
          [ title        (todo-title obj)                    ]
          [ priority     (todo-priority obj)                 ])
      (string-append
       (table-row->string (list id username completed-at created-at description title priority))
       "\n")))

  (generator
   ()
   ;; Header
   (yield "id,username,completed_at,created_at,description,title,priority\n")

   (let ([ limit 200 ])
     (let loop ([ offset 0 ])
       (let ([ batch (get-todos+users conn #:offset offset #:limit limit) ])
         (cond [ (null? batch) eof ]
               [ else          (for ([ t (in-list batch) ])
                                 (yield (create-row t)))
                               (loop (+ offset limit)) ]))))))

(define/contract (get-todos+users conn
                                  #:hide-active    [ hide-active    #f ]
                                  #:hide-completed [ hide-completed #f ]
                                  #:limit          [ limit     1000000 ]
                                  #:offset         [ offset          0 ])
  (->* (connection?)
       (#:hide-active    boolean?
        #:hide-completed boolean?
        #:limit          exact-nonnegative-integer?
        #:offset         exact-nonnegative-integer?)
       list?)

  (define where-clause
    (string-join (filter identity
                         (list
                          "(1=1)"
                          (if hide-active    "(todo.completed_at is not null)" #f)
                          (if hide-completed "(todo.completed_at is null)"     #f)))
                 " and "))

  (define rows (query-rows conn
                           (string-append
                            "select " select-columns ","
                            ;;   7     8             9                10               11
                            "  u.id, u.created_at, u.password_hash, u.password_salt, u.username,"
                            ;;   12       13
                            "  u.email, u.is_admin "
                            "from todo inner join app_user u "
                            "  on todo.user_id = u.id "
                            "where " where-clause " "
                            "order by todo.priority asc, todo.created_at asc "
                            "offset $1 "
                            "limit $2")
                           offset
                           limit))

  (map make-todo+user rows))

(define/contract (is-completed? obj)
  (-> todo? boolean?)
  (if (todo-completed-at obj) #t #f))

(define/contract (read-todo conn id
                            #:include-user     [ include-user     #f ]
                            #:include-comments [ include-comments #f ])
  (->* (connection? integer?)
       (#:include-comments boolean?
        #:include-user boolean?)
       (or/c todo? #f))
  (let ([ row (query-maybe-row conn
                               (string-append
                                "select " select-columns " "
                                "from todo "
                                "where id = $1")
                               id) ])
    (if row
        (let* ([ obj (make-todo row) ]
               [ user-obj (and include-user
                               (read-user conn (todo-user-id obj))) ]
               [ comments (and include-comments
                               (get-comments+user-for-todo conn (todo-id obj))) ])
          (struct-copy todo
                       obj
                       [ user-obj user-obj ]
                       [ comments comments ]))
        #f)))

(define/contract (update-todo conn obj)
  (-> connection? todo? any)
  (query-exec conn
              (string-append
               "update todo "
               "set user_id=$2, completed_at=$3, description=$4, title=$5, priority=$6 "
               "where id=$1")
              (todo-id obj)
              (todo-user-id obj)
              (db-write-timestamptz (todo-completed-at obj))
              (or (todo-description obj) sql-null)
              (or (todo-title obj) sql-null)
              (todo-priority obj)))

;; --------------------------------------------------------------------------------------------
;; Private Implementation
;; --------------------------------------------------------------------------------------------

(define (make-todo row)
  (build-todo (vector-ref row 1) ; user-id
              (vector-ref row 4) ; title
              (vector-ref row 5) ; description
              #:completed-at (db-maybe-timestamptz row 3)
              #:created-at   (sql-timestamp->moment (vector-ref row 2))
              #:id           (vector-ref row 0)
              #:priority     (vector-ref row 6)))

(define (make-todo+user row)
  (let ([ user-obj (build-user (vector-ref row 11)    ; username
                               (vector-ref row 9)     ; password-hash
                               (vector-ref row 10)    ; password-salt
                               #:created-at (sql-timestamp->moment (vector-ref row 8))
                               #:email      (db-safe-str row 12)
                               #:id         (vector-ref row 7)
                               #:is-admin   (vector-ref row 13)) ])
    (build-todo (vector-ref row 1)   ; user-id
                (db-safe-str row 4)  ; title
                (db-safe-str row 5)  ; description
                #:completed-at (db-maybe-timestamptz row 3)
                #:created-at   (sql-timestamp->moment (vector-ref row 2))
                #:id           (vector-ref row 0)
                #:priority     (vector-ref row 6)
                #:user         user-obj)))

;; ---------------------------------------------------------------------------------------------
;; Tests
;; ---------------------------------------------------------------------------------------------

(module+ test
  (require "./user.rkt")

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

  (define sample-username "todofred")
  (define sample-user-pswd "sesame")
  (define sample-user-salt "et36db58gj25svt97mg85bft2")

  (define (create-sample-user conn)
    (let ([ user (build-user sample-username
                             (hash-password sample-user-pswd sample-user-salt)
                             sample-user-salt) ])
      (create-user conn user)))

  (define sample-todo-title "Take out garbage")
  (define sample-todo-description "...don't forget recycling.")

  (define (create-sample-todo conn user-id)
    (let ([ todo (build-todo user-id
                             sample-todo-title
                             sample-todo-description) ])
      (create-todo conn todo)))

  ;; ------------------------------------------------------------------------------------------
  ;; CRUD
  ;; ------------------------------------------------------------------------------------------

  (exec-db-test
   (λ (conn)

     ;; Create a record
     (let* ([ user-id  (create-sample-user conn)         ]
            [ todo-id  (create-sample-todo conn user-id) ]
            [ todo-obj (read-todo conn todo-id)          ])
       (check-equal? (todo-title todo-obj) sample-todo-title)
       (check-equal? (todo-priority todo-obj) default-priority)

       (let ([ updated-todo (struct-copy todo todo-obj
                                         [ priority 7 ]) ])
         ;; Update a record
         (update-todo conn updated-todo))

       (let ([ updated-todo (read-todo conn todo-id) ])
         ;; Verify updated
         (check-equal? (todo-priority updated-todo) 7))

       ;; Delete todo
       (delete-todo conn todo-id)
       (check-false (read-todo conn todo-id))

       ;; Delete user records
       (query-exec conn "delete from app_user"))))

  )
