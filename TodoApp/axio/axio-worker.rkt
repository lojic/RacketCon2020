#lang racket/base

(require "./axio-env.rkt")

(provide axio-worker-thread)

;; --------------------------------------------------------------------------------------------
;; Public Interface
;; --------------------------------------------------------------------------------------------

(define (axio-worker-thread thunk)
  (parameterize ([ current-custodian axio-worker-custodian ])
    (thread thunk)))
