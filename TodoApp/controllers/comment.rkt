#lang racket

(require "../axio/axio.rkt"
         "../permission.rkt"
         "../models/comment.rkt"
         "../models/todo.rkt"
         "../models/user.rkt"
         "../url-generator.rkt")

(require web-server/http)

(provide create
         delete)

;; --------------------------------------------------------------------------------------------
;; Public Interface
;; --------------------------------------------------------------------------------------------

(define/contract (create ctx tid)
  (-> webctx? exact-integer? response?)

  (define conn     (webctx-connection ctx))
  (define user     (webctx-user ctx))
  (define todo-obj (read-todo conn tid #:include-user #t #:include-comments #t))

  (define (notify-user recipient comment)
    (axio-worker-thread
     (thunk
      (let ([ recipient-email (user-email recipient) ])
        (when (non-empty-string? recipient-email)
          (send-email (user-email user)
                      (list recipient-email)
                      "New comment"
                      (list
                       "The following comment was added:"
                       ""
                       (comment-description comment))))))))

  (define (handle-post)
    (let* ([ attrs       (webctx-attributes ctx) ]
           [ comment-obj (comment-from-attributes (user-id user)
                                                  tid
                                                  attrs) ])
      (create-comment conn comment-obj)
      (notify-user (todo-user-obj todo-obj) comment-obj)
      (axio-redirect (flash-set ctx 'info "Comment added")
                     (return-url-or-default attrs (url-for 'show-todo tid)))))

  (if (and (may? user 'view todo-obj)
           (post-method? ctx))
      (if todo-obj
          (handle-post)
          (axio-redirect (flash-set ctx 'info "Todo record not found for Comment")
                         (url-for 'home)))
      (axio-redirect ctx (url-for 'home))))

(define/contract (delete ctx id)
  (-> webctx? exact-integer? response?)

  (define conn (webctx-connection ctx))
  (define obj  (read-comment conn id))
  (define user (webctx-user ctx))

  (if (and (may? user 'delete obj)
           (post-method? ctx))
      (begin
        (delete-comment conn id)
        (axio-redirect (flash-set ctx 'info "Comment deleted")
                       (url-for 'show-todo (comment-todo-id obj))))
      (axio-redirect ctx (url-for 'home))))
