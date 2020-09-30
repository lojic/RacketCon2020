#lang racket

(require "../axio/axio.rkt"
         "../url-generator.rkt"
         "../models/user.rkt")

(require threading
         web-server/http
         web-server/templates)

(provide login
         logout)

;; --------------------------------------------------------------------------------------------
;; Public Interface
;; --------------------------------------------------------------------------------------------

(define/contract (login ctx)
  (-> webctx? response?)

  (define attrs (webctx-attributes ctx))

  (define (handle-post)
    (let* ([ username (hash-ref attrs "username" "") ]
           [ password (hash-ref attrs "password" "") ]
           [ user     (login-user (webctx-connection ctx)
                                  username
                                  password) ])

      (if user
          (~> ctx
              (session-set _ 'userid (user-id user))
              (flash-set _ 'info "Login successful")
              (axio-redirect _ (return-url-or-default attrs "/")))
          (login-view ctx attrs))))

  (if (post-method? ctx)
      (handle-post)
      (login-view ctx attrs)))

(define/contract (logout ctx)
  (-> webctx? response?)

  (~> ctx
      (session-remove _ 'userid)
      (flash-set _ 'info "You have been logged out")
      (axio-redirect _ "/")))

;; --------------------------------------------------------------------------------------------
;; Views
;; --------------------------------------------------------------------------------------------

(define (login-view ctx attrs)
  (axio-render-layout ctx "../views/authentication/login.html"))
