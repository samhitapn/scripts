#!/usr/bin/Rscript

library(dplyr)
library(tidyr)
library(RMySQL)

sample_mapping <- function(amberBafs, percentCutoff = 0.6) {
  simpleBafs = amberBafs %>% mutate(loci = paste0(chromosome ,":", position)) %>% select(sampleId, loci) %>% mutate(het = T)
  spreadBafs = simpleBafs %>% spread(loci, het, fill = F)
  bafMatrix = as.matrix(spreadBafs %>% select(-sampleId))
  matrixResult = bafMatrix %*% t(bafMatrix)
  dfResult = data.frame(matrixResult)
  colnames(dfResult) = spreadBafs$sampleId
  dfResult$sample1 <- spreadBafs$sampleId
  dfResult = dfResult %>% gather(sample2, match, spreadBafs$sampleId)
  
  sampleCounts = dfResult %>% filter(sample1 == sample2) %>% select(sample1, count = match)
  
  sampleMapping = dfResult %>%
    filter(sample1 != sample2) %>%
    left_join(sampleCounts, by = "sample1") %>%
    mutate(matchPercent = match / count) %>%
    filter(matchPercent > percentCutoff) %>%
    mutate(tmp = sample1, sample1 = ifelse(sample1 < sample2, sample1, sample2), sample2 = ifelse(tmp < sample2, sample2, tmp)) %>%
    group_by(sample1, sample2) %>% summarise(matchPercent = max(matchPercent))
  
  return (sampleMapping)
}

patient_mapping <- function(sampleMapping, existingSamples, existingMappings) {
  existingSamples$match = T
  existingMappings$match = T
  
  patientMapping = sampleMapping %>%
    left_join(existingSamples %>% select(sample1 = sampleId, sample1Prior = match), by = "sample1") %>%
    left_join(existingSamples %>% select(sample2 = sampleId, sample2Prior = match), by = "sample2") %>%
    mutate(sample1Prior = ifelse(is.na(sample1Prior), F, T), sample2Prior = ifelse(is.na(sample2Prior), F, T)) %>%
    mutate(patient1 = substr(sample1, 1, 12), patient2 = substr(sample2, 1, 12)) %>%
    filter(patient1 != patient2) %>%
    left_join(existingMappings %>% select(patient1 = sourceId, patient2 = targetId, patient1Prior = match), by = c("patient1", "patient2")) %>%
    left_join(existingMappings %>% select(patient1 = targetId, patient2 = sourceId, patient2Prior = match), by = c("patient1", "patient2")) %>%
    mutate(patient1Prior = ifelse(is.na(patient1Prior), F, T), patient2Prior = ifelse(is.na(patient2Prior), F, T)) %>%
    mutate(
      # First sort alphabetically
      sourceId = ifelse(patient1 > patient2, patient1, patient2),
      targetId = ifelse(patient1 > patient2, patient2, patient1),
      
      # Next, favour existing samples
      xorSamples = xor(sample1Prior, sample2Prior),
      sourceId = ifelse(xorSamples, ifelse(sample1Prior, patient2, patient1), sourceId),
      targetId = ifelse(xorSamples, ifelse(sample1Prior, patient1, patient2), targetId),
      
      # Finally, favour existing mappings
      xorPatients = xor(patient1Prior, patient2Prior),
      sourceId = ifelse(xorPatients, ifelse(patient1Prior, patient1, patient2), sourceId),
      targetId = ifelse(xorPatients, ifelse(patient1Prior, patient2, patient1), targetId)
    ) %>%
    group_by(sourceId, targetId) %>% summarise(matchPercent = max(matchPercent)) %>%
    group_by(targetId) %>% mutate(target_n = n()) %>%
    group_by(sourceId) %>% mutate(source_n = n()) %>%
    arrange(-target_n) %>%
    filter(row_number() == 1) %>%
    select(sourceId, targetId, matchPercent)
  
  patientMapping = patientMapping %>% left_join(existingMappings %>% select(sourceId, targetId, existing = match), by = c("sourceId", "targetId"))
  patientMapping[is.na(patientMapping)] <- T
  
  return (patientMapping %>% arrange(existing, matchPercent))
}

######################## Step 1 - Regenerate patient mappings
dbProd = dbConnect(MySQL(), dbname='hmfpatients', groups="RAnalysis", host = "127.0.0.1")
amberBafs = dbGetQuery(dbProd, "SELECT * FROM amber")
existingSamples = dbGetQuery(dbProd, "SELECT * FROM sampleMapping")
existingMappings = dbGetQuery(dbProd, "SELECT * FROM patientMapping")

dbDisconnect(dbProd)
rm(dbProd)

sampleMapping = sample_mapping(amberBafs)
patientMapping = patient_mapping(sampleMapping, existingSamples, existingMappings)

amberSamples = unique(amberBafs$sampleId)
write.table(amberSamples, file = "~/tmp/samples.csv", quote = F, row.names = F, col.names = F, sep = ",")
write.table(patientMapping %>% select(sourceId, targetId), file = "~/tmp/patient_mapping.csv", quote = F, row.names = F, col.names = F, sep = ",")


######################## Step 2 - Update hashes
# -> Compare to previous samples and patient mapping
# -> Copy both files to /data/common/dbs/idgenerator/input/
# -> Run 'update_hmf_ids'
# -> Update hashes in repo -> build -> assess anonymization is the same as previous for existing samples.
# -> Make new release and deploy -> retest
# -> Recreate patientMapping table (based on patient mapping and remapping) and sampleMapping table (based on anonymized IDs)
