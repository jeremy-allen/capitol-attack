# capitol-attack
Automate the download of all complaints, affidavits, and indictments of the capitol attackers using R

Problem: How do I get all the complaints, affidavits, and indictments (all at once!) for everyone charged so far in the attack on the U.S. Capitol?

Solution: R’s tidyverse is a good way. The rvest package has easy functions for scraping the web.

In this Rmd I use only tidyverse packages. I’ll show exploratory data analysis, how to loop through an HTML table with the rvest and purrr packages, automatically create unique folders on your system for each set of documents, and use the amazing polite package to handle identifying ourselves to the web host and limiting our activity on their server so that we do not cause harm.

