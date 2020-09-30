#lang racket

(require "../axio/axio.rkt"
         "./user.rkt")

(require db)

(provide build-comment
         create-comment
         delete-comment
         comment-from-attributes
         get-comments+user-for-todo
         read-comment
         update-comment
         (struct-out comment))

(struct comment (id
                 user-id
                 user-obj
                 todo-id
                 created-at
                 description)
        #:transparent)

(define select-columns
  ;0   1        2           3            4
  "comment.id, comment.todo_id, comment.created_at, comment.description, comment.user_id")

;; --------------------------------------------------------------------------------------------
;; Public Interface
;; --------------------------------------------------------------------------------------------

(define (build-comment user-id todo-id description
                       #:created-at [ created-at #f ]
                       #:id         [ id         #f ]
                       #:user       [ user-obj   #f ])
  (comment id
           user-id
           user-obj
           todo-id
           created-at
           description))

(define/contract (create-comment conn obj)
  (-> connection? comment? integer?)

  (query-value conn
               (string-append
                "insert into comment"
                " (user_id, todo_id, description) "
                "values"
                " ($1, $2, $3) "
                "returning id")
               (comment-user-id obj)
               (comment-todo-id obj)
               (or (comment-description obj) sql-null)))

(define/contract (delete-comment conn id)
  (-> connection? integer? any)
  (query-exec conn "delete from comment where id = $1" id))

(define (comment-from-attributes user-id todo-id attrs #:accessor [ accessor (λ (o k) (hash-ref o k #f)) ])
  (build-comment user-id
                 todo-id
                 (accessor attrs "description")))

(define/contract (get-comments+user-for-todo conn todo-id)
  (-> connection? exact-integer? list?)

  (define rows (query-rows conn
                           (string-append
                            "select " select-columns ","
                            ;;   5     6             7                8                9
                            "  u.id, u.created_at, u.password_hash, u.password_salt, u.username,"
                            ;;   10       11
                            "  u.email, u.is_admin "
                            "from comment inner join app_user u "
                            " on comment.user_id = u.id "
                            "where todo_id = $1 "
                            "order by comment.created_at desc ")
                           todo-id))

  (map make-comment+user rows))

(define/contract (read-comment conn id)
  (-> connection? integer? (or/c comment? #f))

  (let ([ row (query-maybe-row conn
                               (string-append
                                "select " select-columns " "
                                "from comment "
                                "where id = $1")
                               id) ])
    (if row
        (make-comment row)
        #f)))

(define/contract (update-comment conn obj)
  (-> connection? comment? any)
  (query-exec conn
              (string-append
               "update comment "
               "set user_id=$2, todo_id=$3, description=$4 "
               "where id=$1")
              (comment-id obj)
              (comment-user-id obj)
              (comment-todo-id obj)
              (or (comment-description obj) sql-null)))

;; --------------------------------------------------------------------------------------------
;; Private Implementation
;; --------------------------------------------------------------------------------------------

(define (make-comment row)
  (build-comment (vector-ref row 4) ; user-id
                 (vector-ref row 1) ; todo-id
                 (vector-ref row 3) ; description
                 #:created-at (sql-timestamp->moment (vector-ref row 2))
                 #:id         (vector-ref row 0)))

(define (make-comment+user row)
  (let ([ user-obj (build-user (vector-ref row 9)    ; username
                               (vector-ref row 7)    ; password-hash
                               (vector-ref row 8)    ; password-salt
                               #:created-at (sql-timestamp->moment (vector-ref row 6))
                               #:email      (db-safe-str row 10)
                               #:id         (vector-ref row 5)
                               #:is-admin   (vector-ref row 11)) ])
    (build-comment (vector-ref row 4) ; user-id
                   (vector-ref row 1) ; todo-id
                   (vector-ref row 3) ; description
                   #:created-at (sql-timestamp->moment (vector-ref row 2))
                   #:id         (vector-ref row 0)
                   #:user       user-obj)))

;; ---------------------------------------------------------------------------------------------
;; Tests
;; ---------------------------------------------------------------------------------------------

;; See comment-test.rkt (needed to avoid a circular require issue)
