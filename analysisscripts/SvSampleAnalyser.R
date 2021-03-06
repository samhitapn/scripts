library(purple);
library(RMySQL)
library(data.table)
library(IRanges)
library(dplyr)
library(tidyr)
library(reshape2)
library(ggplot2)
library(stringi)
library(devtools)


# SPECIFIC SAMPLE ANALYSIS


svData = read.csv('~/logs/CLUSTER_V21.csv')
nrow(svData)


specificSample = 'CPCT02060039T'
specificSample = 'COLO829T'

View(svData %>% filter(SampleId=='CPCT02070055T',ClusterId==502))
View(svData)

ssData = svData %>% filter(SampleId==specificSample)
View(ssData)

View(ssData %>% filter(ClusterId==6))

ssData = read.csv("~/logs/CPCT02060039T.csv")

nrow(ssData %>% filter(ClusterId==6) %>% filter(TransType=='TRANS'))
nrow(ssData %>% filter(ClusterId==6) %>% filter(TransType=='SPAN'))
nrow(ssData %>% filter(ClusterId==6) %>% filter(DupBEStart=='true'&DupBEEnd=='true'))
nrow(ssData %>% filter(ClusterId==6) %>% filter(LnkTypeStart=='TI'))
nrow(ssData %>% filter(ClusterId==6) %>% filter(LnkTypeEnd=='TI'))

avgTILen = sum(ssData %>% filter(ClusterId==6))

svData$IsLINE = ifelse(svData$LEStart!='false'|svData$LEEnd!='false',1,0)
svData$IsFS = ifelse(svData$FSStart!='false'|svData$FSEnd!='false',1,0)
svData$Length = ifelse(svData$Type=='BND'|svData$Type=='INS'|svData$ArmEnd!=svData$ArmStart, -1, svData$PosEnd-svData$PosStart)
svData$DoubleDupBE = ifelse(svData$DupBEStart=='true'&svData$DupBEEnd=='true',1,0)
svData$SingleDupBE = ifelse(svData$DoubleDupBE==0&(svData$DupBEStart=='true'|svData$DupBEEnd=='true'),1,0)
svData$IsTI = ifelse(svData$LnkTypeStart=='TI'|svData$LnkTypeEnd=='TI',1,0)
svData$IsDB = ifelse(svData$LnkTypeStart=='DB'|svData$LnkTypeEnd=='DB',1,0)
svData$ShortTICount=ifelse(svData$LnkTypeStart=='TI'&svData$LnkLenStart<=500,1,0)+ifelse(svData$LnkTypeEnd=='TI'&svData$LnkLenEnd<=500,1,0)
# svData$IsDB=ifelse(svData$NearestDBLen>-1&(svData$NearestDBLen<svData$NearestTILen|svData$NearestTILen<30),1,0)
# svData$IsTI=ifelse(svData$NearestTILen>=30&svData$IsDB==0,1,0)
svData$DoubleTI = ifelse(svData$LnkTypeStart=='TI'&svData$LnkTypeEnd=='TI',1,0)
svData$DoubleDB = ifelse(svData$LnkTypeStart=='DB'&svData$LnkTypeEnd=='DB',1,0)
svData$IsSpan = ifelse(svData$TransType=='SPAN',1,0)
svData$IsTrans = ifelse(svData$TransType=='TRANS',1,0)



# common fields
ssData$IsLINE = ifelse(ssData$LEStart!='false'|ssData$LEEnd!='false',1,0)
ssData$IsFS = ifelse(ssData$FSStart!='false'|ssData$FSEnd!='false',1,0)
ssData$IsDB=ifelse(ssData$NearestDBLen>-1&(ssData$NearestDBLen<ssData$NearestTILen|ssData$NearestTILen<30),1,0)
ssData$IsTI=ifelse(ssData$NearestTILen>=30&ssData$IsDB==0,1,0)
ssData$ClusterNone=ifelse(ssData$ClusterCount==1,1,0)
ssData$ClusterSmall=ifelse(ssData$ClusterCount>1&ssData$ClusterCount<=3,1,0)
ssData$ClusterLarge=ifelse(ssData$ClusterCount>3,1,0)

# pre-arm-combined stressed classification
ssData$ArmExpected = ifelse(ssData$ArmExpStart>0,ssData$ArmExpStart,0.1)
ssData$StressedPoissonProb = round(1 - ppois(ssData$ArmCountStart - 1, ssData$ArmExpStart),4)
ssData$IsStressed = ifelse(ssData$StressedPoissonProb <= 0.001 & ssData$ArmCountStart >= 10,1,0)




# speicific cluster or chain data
View(ssData %>% filter(ClusterId==93))

# high level stats
ssStats = (ssData %>% group_by(ClusterSize)
                  %>% summarise(Count=n())
                  %>% arrange(ClusterSize))


View(ssStats)

# group by clusters
ssClusterStats = (ssData %>% group_by(ClusterCount)
           %>% summarise(SvCount=n(),
                         DelPerc=round(sum(Type=='DEL')/n(),2),
                         DupPerc=round(sum(Type=='DUP')/n(),2),
                         InvPerc=round(sum(Type=='INV')/n(),2),
                         BndPerc=round(sum(Type=='BND')/n(),2),
                         FragilePerc=round(sum(FSStart!='false'|FSEnd!='false')/n(),2),
                         LINEPerc=round(sum(LEStart!='false'|LEEnd!='false')/n(),2),
                         StressedPerc=round(sum(IsStressed)/n(),2),
                         DelCount=sum(Type=='DEL'),
                         DupCount=sum(Type=='DUP'),
                         InvCount=sum(Type=='INV'),
                         BndCount=sum(Type=='BND'))
           %>% arrange(ClusterCount))

 View(ssClusterStats)

 # chain and links
 ssChainStats = (ssData %>% filter(ChainId > 0) %>% filter(ChainCount) %>% group_by(ClusterId,ChainId)
                   %>% summarise(SvCount=n(),
                                 LinkCount=first(ChainCount),
                                 DBCount=first(ChainDBCount),
                                 TICount=first(ChainTICount),
                                 DelPerc=round(sum(Type=='DEL')/n(),2),
                                 DupPerc=round(sum(Type=='DUP')/n(),2),
                                 InvPerc=round(sum(Type=='INV')/n(),2),
                                 BndPerc=round(sum(Type=='BND')/n(),2),
                                 FragilePerc=round(sum(FSStart!='false'|FSEnd!='false')/n(),2),
                                 LINEPerc=round(sum(LEStart!='false'|LEEnd!='false')/n(),2),
                                 StressedPerc=round(sum(IsStressed)/n(),2),
                                 DelCount=sum(Type=='DEL'),
                                 DupCount=sum(Type=='DUP'),
                                 InvCount=sum(Type=='INV'),
                                 BndCount=sum(Type=='BND'))
                   %>% arrange(ClusterId,ChainId))

 View(ssChainStats)



# arm summary data
ssArmData = ssData
ssArmData$Chr = ssArmData$ChrStart
ssArmData$Arm = ssArmData$ArmStart
ssArmData$ArmCount = ssArmData$ArmCountStart
ssArmData$ArmExpected = ssArmData$ArmExpStart
ssArmData$Position = ssArmData$PosStart

ssArmBndData = ssData %>% filter(Type=='BND')
ssArmBndData$Chr = ssArmBndData$ChrEnd
ssArmBndData$Arm = ssArmBndData$ArmEnd
ssArmBndData$ArmCount = ssArmBndData$ArmCountEnd
ssArmBndData$ArmExpected = ssArmBndData$ArmExpEnd
ssArmBndData$Position = ssArmBndData$PosEnd

# merge rows prior to arm grouping
ssCombArmData = rbind(ssArmData, ssArmBndData)

# determine IsStressed using poisson distribution using expected vs actual SV counts per arm
ssCombArmData$ArmExpected = ifelse(ssCombArmData$ArmExpected>0,ssCombArmData$ArmExpected,0.1)
ssCombArmData$StressedPoissonProb = round(1 - ppois(ssCombArmData$ArmCount - 1, ssCombArmData$ArmExpected),4)
ssCombArmData$IsStressed = ifelse(ssCombArmData$StressedPoissonProb <= 0.001 & ssCombArmData$ArmCount >= 10,1,0)


# prepare arm stats
ssArmStats = (ssCombArmData %>% group_by(SampleId, Chr, Arm)
            %>% summarise(SvCount=n(),
                          MaxCN=round(max((AdjCNStart+AdjCNEnd)*0.5),2),
                          AvgCN=round(sum((AdjCNStart+AdjCNEnd)*0.5)/n(),2),
                          AvgPloidy=round(sum(Ploidy)/n(),2),
                          ClusteredPerc=round(sum(ClusterCount>1)/n(),2),
                          MaxClusterCount=max(ClusterCount),
                          AvgClusterCount=round(sum(ClusterCount)/n(),0),
                          LEPerc=round(sum(IsLINE==1)/n(),3),
                          FSPerc=round(sum(IsFS==1)/n(),3),
                          DelCount=sum(Type=='DEL'),
                          DelPerc=round(sum(Type=='DEL')/n(),2),
                          DupCount=sum(Type=='DUP'),
                          DupPerc=round(sum(Type=='DUP')/n(),2),
                          InvCount=sum(Type=='INV'),
                          InvPerc=round(sum(Type=='INV')/n(),2),
                          BndCount=sum(Type=='BND'),
                          BndPerc=round(sum(Type=='BND')/n(),2),
                          TICount=sum(IsTI==1),
                          DBCount=sum(IsDB==1),
                          IsStressed=max(IsStressed))
            %>% arrange(SampleId, Chr, Arm))

View(ssArmStats)


# clustering info
clusterStats = (ssData %>% filter(ClusterCount > 1) %>% group_by(ClusterId)
                %>% summarise(SvCount=n(),
                              ChrStartCount=n_distinct(ChrStart),
                              ChrEndCount=n_distinct(ChrEnd),
                              LEPerc=round(sum(IsLINE==1)/n(),3),
                              FSPerc=round(sum(IsFS==1)/n(),3),
                              DelCount=sum(Type=='DEL'),
                              DelPerc=round(sum(Type=='DEL')/n(),2),
                              DupCount=sum(Type=='DUP'),
                              DupPerc=round(sum(Type=='DUP')/n(),2),
                              InvCount=sum(Type=='INV'),
                              InvPerc=round(sum(Type=='INV')/n(),2),
                              BndCount=sum(Type=='BND'),
                              BndPerc=round(sum(Type=='BND')/n(),2),
                              TILen=round(sum(ifelse(IsTI==1,NearestTILen,0)/sum(ifelse(IsTI==1,1,0))),0),
                              IsStressed=max(IsStressed))
                %>% arrange(-SvCount))

View(clusterStats)



ssInfo = (ssData %>% group_by(Type,LengthBucket,IsStressed)
          %>% summarise(Count=n())
          %>% arrange(Type,LengthBucket,IsStressed))

View(ssInfo)

ssTmp1 = (ssData %>% group_by(ChrStart,IsStressed)
          %>% summarise(Count=n(),
                        ArmExpected=first(ArmExpStart),
                        ArmCount=first(ArmCountStart),
                        LongInvCount=sum(Type=='INV'&Length>5e5),
                        LongDelCount=sum(Type=='DEL'&Length>5e5),
                        StressedPP=first(StressedPoissonProb)/n())
          %>% arrange(ChrStart,IsStressed))



