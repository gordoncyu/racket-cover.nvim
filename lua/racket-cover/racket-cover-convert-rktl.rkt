#lang racket
(require json
         racket/list)

;; Helper function to ensure that a value is valid for JSON
(define (valid-json-value? v)
  (and (not (void? v))
       (or (string? v) (number? v) (boolean? v) (null? v) (hash? v))))

;; Manually convert the vector-based srcloc struct into a JSON-friendly object
(define (srcloc->json srcloc)
  (let ([filepath (vector-ref srcloc 1)]
        [offset   (vector-ref srcloc 4)]
        [length   (vector-ref srcloc 5)])
    ;; Ensure filepath is a string
    (unless (string? filepath)
      (set! filepath (format "~a" filepath)))
    ;; Create the hash for JSON
    (hash
     'filepath filepath
     'offset   offset
     'length   length)))

;; Filter out the lists where the first element is #f and process the srcloc entries
(define (process-hash data)
  ;; Process all entries in the data hash
  (for*/list ([(_ file-data) (in-hash data)]  ; Iterate over all key-value pairs in data
              [entry (in-list file-data)]
              #:when (not (first entry)))     ; Only process entries where flag is #f
    (let ([json-data (srcloc->json (second entry))])
      (when (valid-json-value? json-data)
        json-data))))

;; Read the data from the `.rktl` file
(define (read-this-from-file file-path)
  (with-input-from-file file-path
    (lambda ()
      (read))))

;; Main function to process the file and print the JSON output
(define (process-file file-path)
  (define data (read-this-from-file file-path))
  (define result (process-hash data))
  ;; Ensure result is valid for JSON conversion
  (if (null? result)
    (displayln (jsexpr->string (hash)))  ; Outputs {}
    (displayln (jsexpr->string result))))

;; Specify the file path to the `.rktl` file
(define this-file (vector-ref (current-command-line-arguments) 0))

;; Process the file
(process-file this-file)

