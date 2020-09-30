#lang racket/base

(require racket/contract
         racket/match)

(provide axio-init-logger
         axio-log-debug
         axio-log-error
         axio-log-fatal
         axio-log-info
         axio-log-receiver
         axio-log-warning
         axio-logger
         axio-logger-from-symbol)

(define logger #f)

;; --------------------------------------------------------------------------------------------
;; Public Interface
;; --------------------------------------------------------------------------------------------

(define/contract (axio-init-logger level)
  (-> symbol? any)

  (set! logger (make-logger 'axio))

  (axio-log-receiver
   level
   'axio
   (λ (level message data topic)
     (printf "level:~a topic:~a message:~a\n" level topic message)
     (flush-output))))

(define/contract (axio-log-debug str [topic 'axio])
  (->* (string?) (symbol?) any)
  (log-message logger 'debug topic str #f #f))

(define/contract (axio-log-error str [topic 'axio])
  (->* (string?) (symbol?) any)
  (log-message logger 'error topic str #f #f))

(define/contract (axio-log-fatal str [topic 'axio])
  (->* (string?) (symbol?) any)
  (log-message logger 'fatal topic str #f #f))

(define/contract (axio-log-info str [topic 'axio])
  (->* (string?) (symbol?) any)
  (log-message logger 'info topic str #f #f))

(define/contract (axio-log-receiver level topic proc)
  (-> symbol? symbol? (-> symbol? string? any/c symbol? any) any)
  (define log-receiver (make-log-receiver logger level topic))

  (void
   (thread
    (λ ()
      (let loop ()
        (match (sync log-receiver)
          [(vector level message data topic) (proc level message data topic)])
        (loop))))))

(define/contract (axio-log-warning str [topic 'axio])
  (->* (string?) (symbol?) any)
  (log-message logger 'warning topic str #f #f))

(define/contract (axio-logger)
  (-> logger?)
  logger)

(define/contract (axio-logger-from-symbol sym)
  (-> symbol? any)
  (match sym
    [ 'debug   axio-log-debug   ]
    [ 'error   axio-log-error   ]
    [ 'fatal   axio-log-fatal   ]
    [ 'info    axio-log-info    ]
    [ 'warning axio-log-warning ]))
