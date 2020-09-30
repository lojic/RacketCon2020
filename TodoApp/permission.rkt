#lang racket

(require "./models/comment.rkt"
         "./models/todo.rkt"
         "./models/user.rkt")

(provide may?)

;; --------------------------------------------------------------------------------------------
;; Public Interface
;; --------------------------------------------------------------------------------------------

(define/contract (may? user action object)
  (-> user? symbol? any/c boolean?)

  (cond [ (comment? object) (may-comment? user action object) ]
        [ (todo? object)    (may-todo?    user action object) ]
        [ (user? object)    (may-user?    user action object) ]
        [ (symbol? object)  (may-symbol?  user action object) ]
        [ else              #f                                ]))

;; --------------------------------------------------------------------------------------------
;; Private Implementation
;; --------------------------------------------------------------------------------------------

(define (may-comment? user action object)
  (define (user-is-owner? user object)
    (equal? (user-id user) (comment-user-id object)))

  (or (is-admin? user)
      (match action
        [ 'delete (user-is-owner? user object) ]
        [ 'edit   (user-is-owner? user object) ]
        [ 'view   #t                           ]
        [ _       #f                           ])))

(define (may-symbol? user action object)
  (or (is-admin? user)
      (match (list action object)
        [ '(create todo)  #t ]
        [ '(create user)  #t ]
        [ '(export todos) #f ]
        [ _               #f ])))

(define (may-todo? user action object)
  (define (user-is-owner? user object)
    (equal? (user-id user) (todo-user-id object)))

  (or (is-admin? user)
      (match action
        [ 'delete (user-is-owner? user object) ]
        [ 'edit   (user-is-owner? user object) ]
        [ 'view   #t                           ]
        [ _       #f                           ])))

(define (may-user? user action object)
  (define (user-is-owner? user object)
    (equal? (user-id user) (user-id object)))

  (or (is-admin? user)
      (match action
        [ 'delete (user-is-owner? user object) ]
        [ 'edit   (user-is-owner? user object) ]
        [ 'view   #t                           ])))
