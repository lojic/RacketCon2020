#lang racket

(require "../axio/axio.rkt"
         "../models/todo.rkt"
         "../models/user.rkt"
         "../permission.rkt"
         "../url-generator.rkt")

(require gregor
         net/url
         web-server/http
         web-server/templates)

(provide index)

(define session-filter-key "user-index-filter-show")

;; --------------------------------------------------------------------------------------------
;; Public Interface
;; --------------------------------------------------------------------------------------------

(define/contract (index ctx)
  (-> webctx? response?)

  (define conn    (webctx-connection ctx))
  (define request (webctx-request ctx))
  (define user    (webctx-user ctx))
  (define attrs   (webctx-attributes ctx))

  (define (handle-get)
    (let ([ filter (hash-ref attrs "filter-show" #f) ])
      (if filter
          ;; User has specified a filter
          (index-view (session-set ctx session-filter-key filter)
                      attrs
                      (filtered-todos conn filter))
          ;; User has not specified a filter, so use the session value
          (let ([ filter (session-get ctx session-filter-key) ])
            (index-view ctx
                        (hash-set attrs "filter-show" filter)
                        (filtered-todos conn filter))))))

  (if user
      (handle-get)
      (axio-redirect ctx
                     (url-for 'login
                              (hash "return-url" (url->string (request-uri request)))))))

;; --------------------------------------------------------------------------------------------
;; Views
;; --------------------------------------------------------------------------------------------

(define (index-view ctx attrs todos)
  (axio-render-layout ctx "../views/site/index.html"))

;; --------------------------------------------------------------------------------------------
;; Private Implementation
;; --------------------------------------------------------------------------------------------

(define (filtered-todos conn filter)
  (define-values (hide-active hide-completed)
    (match filter
      [ "all"       (values #f #f) ]
      [ "active"    (values #f #t) ]
      [ "completed" (values #t #f) ]
      [ _           (values #f #f) ]))

  (get-todos+users conn
                   #:hide-active    hide-active
                   #:hide-completed hide-completed))
