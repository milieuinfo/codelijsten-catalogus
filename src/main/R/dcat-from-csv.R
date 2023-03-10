#!/usr/bin/Rscript
library(xml2)
library(tidyr)
library(dplyr)
library(jsonlite)
library(data.table)
library(stringr)

#setwd('/home/gehau/git/codelijsten-catalogus/src/main/R')


##### FUNCTIES

# functie om dataframe om te zetten naar jsonld
to_jsonld <- function(dataframe) {
  # lees context
  context <- jsonlite::read_json("../resources/source/context.json")
  # jsonld constructie
  df_in_list <- list('@graph' = dataframe, '@context' = context)
  df_in_json <- toJSON(df_in_list, auto_unbox=TRUE)
  return(df_in_json)
}

### functie om de volgende release versie juist te zetten
prompt_versie <- function(version_next_release) {
  cat(paste("Is de volgende release versie : ",version_next_release,'?\n'))
  cat(" (y/n)  : ")
  yes_or_no <- readLines("stdin",n=1);
  if ( yes_or_no == 'y') {
    return(version_next_release)
  } else if ( yes_or_no == 'n') {
    cat(" Wat is de volgende release versie?  : ")
    version_next_release <- readLines("stdin",n=1)
    prompt_versie(version_next_release)
  } else {
    cat("enter y or n\n")
    prompt_versie(version_next_release)
  }
}

expand_df_on_pipe <- function(df) {
  # verdubbel rijen met pipe separator
  for(col in colnames(df)) {   # for-loop over columns
    df <- df %>%
      separate_rows(col, sep = "\\|")%>% 
      distinct()
  }
  return(df)
}

collapse_df_on_pipe <- function(df) {
  # group by 
  df3 <- df %>% select(id) %>% distinct()
  for(col in colnames(df)) {   # for-loop over columns
    if ( col != 'id') {
      df4 <- df %>% select(id, col)   
      names(df4)[2] <- 'naam' # hack, geef de tweede kolom een vaste naam, summarize werkt niet met variabele namen
      df2 <- df4 %>% group_by(id) %>% 
        summarize(naam = paste(sort(unique(naam)),collapse="|")) 
      names(df2)[2] <- col # wijzig kolom met naam 'naam' terug naar variabele naam
      df3 <- merge(df3, df2, by = "id")
    }
  }
  return(df3)
}


update_version <- function(df) {
  setDT(df)[type == "dcat:Catalog", owl.versionInfo := version_next_release]
  setDT(df)[type == "dcat:Catalog", issued := issued_]
  setDT(df)[type == "spdx:Catalog", versionInfo := version_next_release]
  return(df)
}

add_package_as_distribution <- function(df) {
  #ds <- df[df$type == 'spdx:Package', ]['id']
  ds <- subset(df, type == 'spdx:Package')$id
  setDT(df)[type == "dcat:Dataset", distribution := paste(distribution,ds, sep = "|")]
  setDT(df)[type == "spdx:Package", type := paste(type,'dcat:Distribution', sep = "|")]
  
  return(df)
}

rename_columns <- function(df) {
  # rename columns
  df <- df %>%
    rename(  "@id" = id,
             "@type" = type)

  return(df)
}

#### START SCRIPT

#### PARSE POM.XML SET VARIABLES
artifactory <- "https://repo.omgeving.vlaanderen.be/artifactory/release"
# read pom.xml 
x <- read_xml("../../../pom.xml")
xml_ns_strip( x )
groupId <- xml_text( xml_find_first(x, "/project/groupId") )
artifactId <- xml_text( xml_find_first(x, "/project/artifactId") )
version <- xml_text( xml_find_first(x, "/project/version") )
name <- xml_text( xml_find_first(x, "/project/name") )
class_path  <- gsub("\\.","/", groupId) 
version_next_release <- sub("-SNAPSHOT", "", version)
version_next_release <- prompt_versie(version_next_release)
packageFileName_ <- paste(name,'-',version_next_release,'.jar', sep = "")
packageName_ <- paste(groupId, name, sep = ".")
package_id <- paste(paste("omg_package", packageName_, sep = ":"),version_next_release, sep = ".")
downloadLocation_ <- paste(artifactory, class_path, name, version_next_release, packageFileName_, sep = "/")

issued_ <- format(Sys.Date())


### MAAK DATAFRAME VAN METADATA CSV
df <- read.csv(file = "../resources/source/catalog_source.csv", sep=",", na.strings=c("","NA"))


df <- expand_df_on_pipe(df)


df <-   update_version(df)

#df <- add_package_as_distribution(df)

write.csv(collapse_df_on_pipe(df),"../resources/be/vlaanderen/omgeving/data/id/catalog/codelijsten-catalogus/catalog.csv", row.names = FALSE)

df <- df %>%
  mutate_all(list(~ str_c("", .)))

df <-   expand_df_on_pipe(df)%>% 
  rename_columns()



### JSONLD RDF UIT DATAFRAME
df_in_json <- to_jsonld(df)

tmp_file <- tempfile(fileext = ".jsonld")

write(df_in_json, tmp_file)

### CLEAN RDF

system(paste("riot --formatted=TURTLE ", tmp_file, " > ../resources/be/vlaanderen/omgeving/data/id/catalog/codelijsten-catalogus/catalog.ttl"))
system("riot --formatted=JSONLD ../resources/be/vlaanderen/omgeving/data/id/catalog/codelijsten-catalogus/catalog.ttl > ../resources/be/vlaanderen/omgeving/data/id/catalog/codelijsten-catalogus/catalog.jsonld")




