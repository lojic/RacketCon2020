#lang racket

;; This separate test file was necessary to avoid a circular require dependency.

(module+ test
  (require "../axio/axio.rkt"
           "./comment.rkt"
           (prefix-in todo: "./todo.rkt")
           "./user.rkt")

  (require db
           rackunit)

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

  (define sample-username "commentfred")
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
    (let ([ todo (todo:build-todo user-id
                                  sample-todo-title
                                  sample-todo-description) ])
      (todo:create-todo conn todo)))

  (define sample-comment-description "a comment description")

  (define (create-sample-comment conn user-id todo-id)
    (let ([ comment (build-comment user-id
                                   todo-id
                                   sample-comment-description) ])
      (create-comment conn comment)))

  ;; ------------------------------------------------------------------------------------------
  ;; CRUD
  ;; ------------------------------------------------------------------------------------------

  (exec-db-test
   (λ (conn)

     ;; Create a record
     (let* ([ user-id     (create-sample-user conn)            ]
            [ todo-id     (create-sample-todo conn user-id)    ]
            [ comment-id  (create-sample-comment conn user-id todo-id) ]
            [ comment-obj (read-comment conn comment-id)          ])
       (check-equal? (comment-description comment-obj) sample-comment-description)

       (let ([ updated-comment (struct-copy comment comment-obj
                                            [ description "new desc" ]) ])
         ;; Update a record
         (update-comment conn updated-comment))

       (let ([ updated-comment (read-comment conn comment-id) ])
         ;; Verify updated
         (check-equal? (comment-description updated-comment) "new desc"))

       ;; Delete comment
       (delete-comment conn comment-id)
       (check-false (read-comment conn comment-id))

       ;; Delete other records
       (todo:delete-todo conn todo-id)
       (delete-user conn user-id))))

  )
