#lang racket/base

(provide (struct-out axio-context))

;; --------------------------------------------------------------------------------------------
;; Public Interface
;; --------------------------------------------------------------------------------------------

(struct axio-context (app-env-id
                      db-conn)
        #:transparent)
