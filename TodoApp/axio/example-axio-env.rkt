#lang racket/base

(require racket/contract
         racket/match)

;; Environment specific (e.g. production, staging, development) values.
;; This file is not kept in source control, so it can also be used for secrets.

(provide axio-smtp-password
         axio-smtp-port
         axio-smtp-server
         axio-smtp-username
         ;axio-web-app-secret
         get-app-env
         (struct-out app-env))

(struct app-env (db-database
                 db-password
                 db-server
                 db-username)
        #:transparent)

(define axio-smtp-password "example-smtp-password")
(define axio-smtp-port     25)
(define axio-smtp-server   "example-smtp-host")
(define axio-smtp-username "example-smtp-username")

;; Commented out to ensure a proper secret is used
;; (define axio-web-app-secret #"replace-this-with-random-characters")

(define/contract (get-app-env env-type)
  (-> symbol? app-env?)
  (match env-type
    [ 'production (app-env
                   "production-database-name"
                   #f
                   "localhost"
                   "production-database-username") ]
    [ 'test       (app-env
                   "test-database-name"
                   #f
                   "localhost"
                   "test-database-username") ]
    [ _           #f ]))
