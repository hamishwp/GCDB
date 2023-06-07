# Read in all the necessary libraries and GCDB scripts
source("./RCode/Setup/GetPackages.R")

# Extract the impact databases, focussing specifically on the provided hazard
GetImpacts<-function(haz="EQ"){
  # Desinventar
  impies<-GetDesinventar(haz=haz)
  # EM-DAT
  impies%<>%rbind(GetEMDAT(haz=haz))
  # GIDD (IDMC)
  impies%<>%rbind(GetGIDD(haz=haz))
  
  return(impies)
}

# Match the impacts to hazard data
MatchImpHaz<-function(impies,haz="EQ"){
  # First check GDACS
  hazzies<-MatchGDACS(impies,haz)
  # Then match by hazard
  #@@@@@### EARTHQUAKES @@@@@@@@#
  if(haz=="EQ"){
    hazzies%<>%MatchUSGS(impies=impies)
  #@@@@@@@@@@ FLOODS @@@@@@@@@@@#
  } else if(haz=="FL"){
    stop("Not ready yet... sorry!")
    hazzies%<>%MatchCloud2Street(impies=impies)
  #@@@@@ TROPICAL CYCLONES @@@@@#
  } else if(haz=="TC"){
    stop("Not ready yet... sorry!")
    hazzies%<>%MatchNOAA_TC(impies=impies)
  #@@@@@@@@@@ STORMS @@@@@@@@@@@#
  } else if(haz=="ST"){
    stop("Not ready yet... sorry!")
    hazzies%<>%MatchNOAA_ST(impies=impies)
  } else stop("Hazard code not recognised, example: 'EQ'")
  
  return(hazzies)
}

saveGCDB<-function(GCDBy){
  saveRDS(GCDBy,paste0("./CleanedData/GCDB/",GCDBy$info$GCDB_ID))
  return(T)
}

# Taking the wrangled impact, hazard, and their associated geospatial elements,
# this function forms the GCDB objects required
FormGCDBevents<-function(impies,cores=1){
  # Parallelise it and output the check directly
  do.call(rbind,mclapply(impies$GCDB_ID, function(id){
    # Extract geospatial hazard data
    # (can be multiple impacts, multiple hazards, multiple impact types & multiple hazard types)
    GCDBy<-tryCatch(PairImpHaz(impies=impies[impies$GCDB_ID==id,]),error=function(e) NA)
    # Check to see if all went well, if not, return fail
    if(class(GCDBy)!="GCDB") return(data.frame(GCDB_ID=id,checker=F))
    # Extract geospatial impact data (e.g. aggregated admin boundaries)
    GCDBy<-tryCatch(PairImpPoly(GCDBy=GCDBy,impies=impies[impies$GCDB_ID==id,]),error=function(e) NA)
    # All-or-nothing approach: the impact polygon data should not fail!!!
    if(class(GCDBy)!="GCDB") return(data.frame(GCDB_ID=id,checker=F))
    # Store it out! Bespoke function, returning TRUE if not problems saving out
    checker<-saveGCDB(GCDBy)
    
    return(data.frame(GCDB_ID=id,checker=checker))
  },mc.cores=cores))

}

GO_GCDB<-function(lhaz,cores=1){
  
  do.call(rbind,lapply(lhaz,function(haz){
    # Get the impacts for the specific hazard (inc. associated hazard-impacts)
    impies<-GetImpacts(haz=haz)
    # Get the matched
    hazzies<-MatchImpHaz(impies,haz="EQ")
    # Form the GCDB event objects and save out
    checker<-FormGCDBevents(impies,cores=cores); checker$hazard=haz
    
    return(checker)
  }))
  
}

# Which hazards do we want to extract?
lhaz<-c("EQ") # c("EQ","FL","TC","ST")
# Level of parallelisation (modify accordingly)
cores<-max(c(round(parallel::detectCores()/2),1))
print(paste0("Number of cores to be used by GCDB = ",cores))
# Extract the data!
checker<-GO_GCDB(lhaz,cores=cores)









