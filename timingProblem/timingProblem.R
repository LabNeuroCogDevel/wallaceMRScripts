library(dplyr); library(ggplot2)

#dicom_hinfo -tag 0008,0032 /data/Luna1/Raw/{MultiModal/10997_20140308/,MRCTR/10152_20111123/,P5Sz/11360_20150129}/*[Rr]est*/* > 3times.MRtimes 
df <- read.table('3times.MRtimes')
names(df) <- c('file','MRtime')

#mrtime: HHMMSS.s, want seconds
MRtoSecExp <- gsub('(\\d{2})(\\d{2})([0-9.]+)','\\1*60*60 + \\2*60 + \\3',df$MRtime)
df$time <- sapply(MRtoSecExp, function(x) eval(parse(text=x))  )

# get protocol from filename
# make time relative to start of protocol
# add diff between times as attribute
d<- df %>%
   mutate( prtcl = gsub('.*(P5|MRCTR|MultiModal).*','\\1',file) ) %>%
   mutate( prtcl = ifelse(prtcl=='MRCTR','Reward',prtcl) ) %>%
   group_by(prtcl) %>%
   mutate(reltime = time-first(time),
          tdiff=round(c(0,diff(time)),1),
          i=1:n() )

# plot
p<-ggplot(d,aes(x=i,y=reltime,color=as.factor(tdiff),size=as.factor(tdiff) )  ) +
   geom_point()+
   facet_grid(.~prtcl) +
   ylab('time - 1st dicom')+xlab('dicom num.')+
   ggtitle('DCM Acq Times for 3 MRCTR Protocols')+ theme_bw()

ggsave('TRs.png',p)
