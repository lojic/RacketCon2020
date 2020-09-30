#lang racket/base

(require "./axio.rkt")

(require (prefix-in lift: web-server/dispatchers/dispatch-lift)
         (prefix-in log:  web-server/dispatchers/dispatch-log)
         (prefix-in seq:  web-server/dispatchers/dispatch-sequencer)
         web-server/web-server)

(provide axio-app-init)

;; --------------------------------------------------------------------------------------------
;; Public Interface
;; --------------------------------------------------------------------------------------------

(define (axio-app-init environment route get-user)
  (let* ([ instance-id  (string->number (vector-ref (current-command-line-arguments) 0)) ]
         [ env          (get-app-env environment)                                        ]
         [ port         (+ (app-env-port-base env) instance-id)                          ]
         [ axio-context (axio-init environment)                                          ])
    (void
     (serve
      #:dispatch (seq:make (log:make #:format log:extended-format
                                     #:log-path (format "~a.log" (symbol->string environment)))
                           (lift:make (λ (request)
                                        (front-controller axio-context request route get-user))))
      #:port port))

    (do-not-return)))

;; --------------------------------------------------------------------------------------------
;; Private Implementation
;; --------------------------------------------------------------------------------------------

(define (front-controller axioctx request route get-user)
  (define (logged-in-user conn session)
    (and session
         (let ([ userid (hash-ref session 'userid #f) ])
           (and userid
                (integer? userid)
                (get-user conn userid)))))

  (define conn    (axio-context-db-conn axioctx))
  (define session (get-session request conn))
  (define user    (logged-in-user conn session))

  (define (run)
    (define (handle-exception e)
      ((error-display-handler) (exn-message e) e)
      (render-string "<html><body>An error has occurred</body></html>"))

    (with-handlers ([ exn:fail? handle-exception ])
      (let* ([ ctx (webctx request
                           (form-values request)
                           session
                           conn
                           axioctx
                           user) ])
        (route ctx))))

  (dynamic-wind void
                run
                void))
