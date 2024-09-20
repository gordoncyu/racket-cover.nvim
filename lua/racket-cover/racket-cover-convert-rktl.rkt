#lang racket
(require json
         racket/list)

;; Read the data from the `.rktl` file
(define (read-this-from-file file-path)
  (with-input-from-file file-path
    (lambda ()
      (read))))

;; Main function to process the file and print the JSON output
(define (process-file file-path)
  (define data (read-this-from-file file-path))
  
  ;; Process the data into the desired JSON structure
  (define result
    (let ([files-hash (make-hash)])
      ;; Iterate over all files in data
      (for ([file (in-hash-keys data)])
        (define file-data (hash-ref data file))
        ;; Collect uncovered entries
        (define uncovered-list
          (for/list ([entry (in-list file-data)]
                     #:when (not (first entry)))
            ;; For each uncovered entry, extract offset and length
            (let ([srcloc (second entry)])
              (let ([offset (vector-ref srcloc 4)]
                    [length (vector-ref srcloc 5)])
                (hash 'offset offset
                      'length length)))))
        ;; Create the file entry with 'uncovered' key
        (define file-entry (hash 'uncovered uncovered-list))
        ;; Add the file entry to the files hash
        (hash-set! files-hash (string->symbol file) file-entry))
      ;; Return the top-level hash
      (hash 'files files-hash)))
  
  ;; Output the JSON
  (displayln (jsexpr->string result)))

;; Specify the file path to the `.rktl` file
(define this-file (vector-ref (current-command-line-arguments) 0))

;; Process the file
(process-file this-file)
