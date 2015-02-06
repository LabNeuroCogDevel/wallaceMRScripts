library(dplyr); library(ggplot2)
#dicom_hinfo -tag 0008,0032 /data/Luna1/Raw/{MultiModal/10997_20140308/,MRCTR/10152_20111123/,P5Sz/11360_20150129}/*[Rr]est*/* > 3times.MRtimes 
df <- read.table('3times.MRtimes')
names(df) <- c('file','time')
d<- df %>%
   mutate( prtcl = gsub('.*(P5|MRCTR|MultiModal).*','\\1',file) ) %>%
   group_by(proj) %>%
   mutate(reltime = time-first(time),
          tdiff=round(c(0,diff(time)),1),
          i=1:n() )

p<-ggplot(d,aes(x=i,y=reltime,color=prtcl,size=as.factor(tdiff) )  ) +
   geom_point()+
   theme_bw()
