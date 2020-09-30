#lang racket/base

(require "./axio-session.rkt"
         "./axio-web-ctx.rkt")

(require racket/contract
         web-server/http
         web-server/http/redirect)

(provide axio-redirect)

;; --------------------------------------------------------------------------------------------
;; Public Interface
;; --------------------------------------------------------------------------------------------

(define/contract (axio-redirect ctx
                       uri
                       [ status see-other ]
                       #:headers [ headers (list) ])
  (->* (webctx? string?)
       (redirection-status?
        #:headers list?)
       response?)
  (let* ([ headers (cons (cookie->header (create-session-cookie (webctx-session ctx)))
                         headers)  ])
    (redirect-to uri status #:headers headers)))
