library(tidyverse)
library(fs)
library(googleCloudStorageR)

# check bucket contents
bucket_contents <- gcs_list_objects("capitol-docs")
# delete contents
map(bucket_contents$name, gcs_delete_object, bucket = "capitol-docs")

closeAllConnections()
gc()

my_dir <- "/Users/jeremyallen/Dropbox/Data/capitol-attack"

# list files for upload
my_files <- dir_ls(
  path    = here::here("defendants"),
  glob    = "*.pdf",
  recurse = TRUE
) %>% unique()

total <- length(my_files)

# gcs_create_bucket(
#  "capitol-docs",
#  project_id,
#  location      = "US",
#  storageClass  = "STANDARD",
#  predefinedAcl = "publicRead",
#  predefinedDefaultObjectAcl = "bucketOwnerFullControl"
# )

# modify boundary between simple and resumable uploads
# By default the upload_type will be 'simple' if under 5MB, 'resumable' if over 5MB. Use gcs_upload_set_limit to modify this boundary - you may want it smaller on slow connections, higher on faster connections. 'Multipart' upload is used if you provide a object_metadata.
gcs_upload_set_limit(upload_limit = 2500000L)

options(googleAuthR.verbose=2)

mlog <- file("msg.txt", open = "a")
sink(file = "out.txt", append = TRUE, type = "output")
sink(mlog, append = TRUE, type = "message")



 #---- ROUND 1: TRY TO UPLOAD ALL FILES ----

write(x = as.character(Sys.time()), file = paste0(my_dir, "/log.txt"), append = TRUE)

# upload
for (i in seq_along(my_files)) {
  
  skip_to_next <- FALSE
  #closeAllConnections()
  #Sys.sleep(.5)
  message("... ", i, " of ", total, " ... trying to upload ",  path_file(my_files[i]))
 
  tryCatch(
    
   expr = 
   {
    gcs_upload(
     file = my_files[i],
     bucket = "capitol-docs",
     name = path_file(my_files[i]),
     predefinedAcl = "bucketLevel"
    )
   },
   error = function(e) {
    message("... Upload seems to have failed for ", i, ":\n")
    write(x = paste0(my_files[i], "\n", e), file = paste0(my_dir, "/log.txt"), append = TRUE)
    skip_to_next <<- TRUE
   }
   
  )

  if(skip_to_next) { next }
  
}




#---- ROUND 2: TRY FAILED FILES AGAIN ----

write(x = as.character(Sys.time()), file = paste0(my_dir, "/log2.txt"), append = TRUE)

my_failed_files <- readr::read_lines("log.txt") %>% 
  as_tibble() %>% 
  filter(str_detect(value, "pdf$")) %>% 
  drop_na() %>% 
  pull(value)

new_total <- length(my_failed_files)

# upload
for (i in seq_along(my_failed_files)) {
  
  skip_to_next <- FALSE
  closeAllConnections()
  Sys.sleep(.5)
  message("... ", i, " of ", new_total, " ... trying to upload ",  path_file(my_failed_files[i]))
  
  tryCatch(
    
    expr = 
      {
        gcs_upload(
          file = my_failed_files[i],
          bucket = "capitol-docs",
          name = path_file(my_failed_files[i]),
          predefinedAcl = "bucketLevel"
        )
      },
    error = function(e) {
      message("... Upload seems to have failed for ", i, ":\n")
      write(x = paste0(my_failed_files[i], "\n", e), file = paste0(my_dir, "/log2.txt"), append = TRUE)
      skip_to_next <<- TRUE
    }
    
  )
  
  if(skip_to_next) { next }
  
}

closeAllConnections()
gc()




#---- ROUND 3: TRY FAILED FILES FROM ROUND 2 AGAIN ----

write(x = as.character(Sys.time()), file = paste0(my_dir, "/log3.txt"), append = TRUE)

my_failed_files2 <- readr::read_lines("log2.txt") %>% 
  as_tibble() %>% 
  filter(str_detect(value, "pdf$")) %>% 
  drop_na() %>% 
  pull(value)

new_total2 <- length(my_failed_files2)

# upload
for (i in seq_along(my_failed_files2)) {
  
  skip_to_next <- FALSE
  closeAllConnections()
  Sys.sleep(.5)
  message("... ", i, " of ", new_total2, " ... trying to upload ",  path_file(my_failed_files2[i]))
  
  tryCatch(
    
    expr = 
      {
        gcs_upload(
          file = my_failed_files2[i],
          bucket = "capitol-docs",
          name = path_file(my_failed_files2[i]),
          predefinedAcl = "bucketLevel"
        )
      },
    error = function(e) {
      message("... Upload seems to have failed for ", i, ":\n")
      write(x = paste0(my_failed_files2[i], "\n", e), file = paste0(my_dir, "/log3.txt"), append = TRUE)
      skip_to_next <<- TRUE
    }
    
  )
  
  if(skip_to_next) { next }
  
}

sink(NULL, type = "message")
sink(NULL, type = "output")

closeAllConnections()
gc()
