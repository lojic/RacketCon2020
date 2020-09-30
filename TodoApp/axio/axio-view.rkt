#lang racket/base

(require "./axio-session.rkt"
         "./axio-web-ctx.rkt")

(require (for-syntax racket/base)
         (for-syntax racket/syntax)
         web-server/http
         web-server/http/response-structs
         web-server/templates
         xml)

(provide axio-render-template
         h
         axio-render-layout
         render-string)

;; --------------------------------------------------------------------------------------------
;; Public Interface
;; --------------------------------------------------------------------------------------------

(define (axio-render-template ctx temp #:headers [ headers (list) ])
  (let* ([ session (clear-flash (webctx-session ctx))     ]
         [ cookie  (create-session-cookie session)        ]
         [ headers (cons (cookie->header cookie) headers) ])
    (render-string temp #:headers headers)))

;; h is for "html escape" inspired by Rails
(define (h str) (xexpr->string str))

(define (render-string str #:headers [ headers null ])
  (response
   200
   #"OK"
   (current-seconds)
   TEXT/HTML-MIME-TYPE
   headers
   (λ (op)
     (write-bytes (string->bytes/utf-8 str) op))))

(define-syntax (axio-render-layout stx)
  (syntax-case stx ()
    [(_ ctx body-template)
     (with-syntax ([ body (format-id #'ctx "body") ]
                   [ layout-template (datum->syntax #'ctx "../views/layouts/application.html") ])
       #'(axio-render-template ctx
                               (let ([ body (include-template body-template) ])
                                 (include-template layout-template))))]
    [(_ ctx body-template layout-template)
     (with-syntax ([ body (format-id #'ctx "body") ])
       #'(axio-render-template ctx
                               (let ([ body (include-template body-template) ])
                                 (include-template layout-template))))]
    ))
