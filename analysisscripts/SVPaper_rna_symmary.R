source("../analysisscripts/libSVPaper.R")

dnaRnaCombinedOutputData = read.csv(paste0(dropbox, "/../Toolkit Paper/supp/supptable3_LINX_dna_rna_fusion_comparison.csv"))
dnaRnaSummary = dnaRnaCombinedOutputData %>% filter(KnownCategory!='Unknown') %>% group_by(MatchType,KnownCategory) %>% count()
plotColours = c('royal blue','skyblue3','lightblue')
dnaRnaSummaryPlot = (ggplot(dnaRnaSummary , aes(x=KnownCategory, y=n, fill=MatchType))
                     + geom_bar(stat = "identity", colour = "black", position = position_stack(reverse = TRUE))
                     + labs(x = "", y="Fusions", fill='Fusion Prediction', title = "")
                     + scale_fill_manual(values = plotColours)
                     + theme_bw() + theme(panel.grid.minor.x = element_blank(), panel.grid.major.x = element_blank())
                     + theme(panel.grid.minor.y = element_blank(), panel.grid.major.y = element_blank())
                     + theme(axis.text.x = element_text(angle=90, hjust=1),legend.text=element_text())
                     + coord_flip())
dnaRnaSummaryPlot
figsave("dnaRnaSummaryPlot", dnaRnaSummaryPlot, width=4, height=2)
