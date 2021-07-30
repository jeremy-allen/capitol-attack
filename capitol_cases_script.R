#! /usr/local/bin/RScript

library(assertthat)
library(here)
library(rvest)
library(polite)
library(fs)
library(tidyverse)

my_dir <- "/Users/jeremyallen/Dropbox/Data/capitol-attack/defendants"

# confirm or create defendants folder and defendant folder
if (!dir_exists(my_dir)) {
  dir_create(my_dir)
}

#---- get page HTML contents ----

cases_url <- "https://www.justice.gov/usao-dc/capitol-breach-cases"

# from the polite package, we properly identify ourselves and respect any explicit limits
session <- bow(cases_url, force = TRUE)

# scrape the page contents
cases_page <- scrape(session)

number_of_docs <- cases_page %>% # making the link_urls column
 html_nodes("td") %>% 
 html_nodes("a") %>%
 html_attr('href') %>% 
 unique() %>% 
 str_detect("download$") %>% 
 sum() # no duplicates


#---- build function that will download all the docs ----

download_defendant_docs <- function(row) {
 
 # get the defendant's name
 # get list of download urls for their documents
 # create a filename no longer than 45 characters for each document
 # download docs into folder named after defendant
 
 message("**************************************************")
 
 defendant <- row %>%
  html_children() %>% 
  html_text() %>% 
  first()
 
 if (nchar(defendant) > 0) {
  defendant <- defendant %>%
   str_replace_all("&", "and") %>% 
   str_replace_all("[^a-zA-Z0-9]", "_") %>% # replace all non alpha-numeric
   str_replace_all("_{2,3}", "_") %>% # replace extra underscores with single underscore
   str_remove("[^a-zA-Z0-9]$") %>% # remove any non-alpha-numeric at the end
   map(~str_remove(., "^[-_]{1,2}")) %>% # and at the beginning
   str_to_lower()
 } else {
  defendant <- "no_name"
 }
 
 # limit defendant names to 45 characters
 if (nchar(defendant) > 45) {
  defendant <- str_extract(defendant, "^.{45}")
 }
 
 assert_that(
  inherits(defendant, "character"),
  length(defendant) > 0
 )
 
 urls_to_download <- row %>%
  html_children() %>% 
  html_nodes("a") %>% 
  html_attr("href") %>% 
  map(~str_c("https://www.justice.gov", .)) # prepend missing domain on all links
 
 assert_that(
  inherits(urls_to_download, "list"),
  length(urls_to_download) > 0,
  map(urls_to_download, is.na) %>% unlist() %>% sum() == 0
 )
 
 doc_names <- row %>%
   html_children() %>% 
   html_nodes("li") %>% # doc links are in html list tags
   html_text() %>% 
   as.list() %>% 
   map(~str_remove(., ".pdf")) %>% # a few filenames have .pdf inside the filename
   map(~str_replace_all(., "&", "and")) %>% 
   map(~str_replace_all(., "[^a-zA-Z0-9]", "_")) %>% # replace all non alpha-numeric
   map(~str_replace_all(., "_{2,3}", "_")) %>% # replace extra underscores with single underscore
   map(~str_to_lower(.)) %>%
   map(~str_remove(., "^[-_]{1,2}")) %>% 
   map(~str_trim(.)) %>% 
   # limit filenames to 45 characters
   modify_if(.p = ~nchar(.x) > 45, .f = ~str_extract(.x, "^.{45}")) %>% 
   map(~str_c(., ".pdf")) # append .pdf to all filenames
 
 assert_that(
  inherits(doc_names, "list"),
  length(doc_names) > 0,
  map(doc_names, is.na) %>% unlist() %>% sum() == 0
 )
 
 assert_that(
  length(urls_to_download) == length(doc_names)
 )
 
 message(str_c("... downloading for: ", defendant, "\n"))
 
 if (!dir_exists(str_c(my_dir, "/", defendant))) {
  dir_create(str_c(my_dir, "/", defendant))
 }
 
 # ---- politely download the files (will wait 5 seconds between each) ----
 
 # function that will take a url and filename and do the downloads
 get_doc <- function(url , filename) {
  nod(session, url) %>%
   rip(destfile = filename,
       path = str_c(my_dir, "/", defendant),
       overwrite = TRUE)
 }
 
 current_num <- length(list.files(my_dir, recursive = TRUE))
 
 message(
  str_c(
   "... ", current_num, " pdf files downloaded so far", "\n",
   "... downloading the next ", length(urls_to_download), " now", "\n\n\n"
  )
 )
 
 # pmap our function over the two columns
 list(url = urls_to_download, filename = doc_names) %>% 
  pmap(safely(get_doc)) # wrapped in safely so it won't stop on error
 
}




#---- download docs ----

# Let's get the contents of each row into a list but drop the header row.
rows <- cases_page %>%
 html_nodes("tr") %>% 
 map(~html_nodes(., "td")) %>% # gets cell content per row
 compact() # drops empty header row

# Now we can iterate through each element of this list (a row from the html table)
# and do whatever we want. Let's create a function to do what we want, then map
# that function over each element of this list.

write(x = as.character(Sys.time()), file = "/Users/jeremyallen/Dropbox/Data/capitol-attack/log.txt", append = TRUE)

# start: direct errors and messages to log
con <- file("/Users/jeremyallen/Dropbox/Data/capitol-attack/log.txt")
sink(con, append=TRUE, type = "output", split = TRUE)
#sink(con, append=TRUE, type="message")

message(
 str_c(
  "\n\n*****************************************************************************\n",
  "Session time: ", Sys.time(), "\n",
  "There are ", length(rows), " rows from wich to download documents", "\n",
  "There are ", number_of_docs, " documents to download", "\n",
  "There will be a 5-second pause between each document", "\n",
  "See https://dmi3kno.github.io/polite/reference/set_delay.html for more details", "\n\n"
 )
)

# download all the docs
map(rows, download_defendant_docs)

final_num <- length(list.files("/Users/jeremyallen/Dropbox/Data/capitol-attack/defendants", recursive = TRUE))

message(
 str_c(
  "... ", final_num, " pdfs were downloaded in total", "\n"
 )
)

# stop: direct errors and messages to log; restore to console
sink(type = "output")
#sink(type = "message")
