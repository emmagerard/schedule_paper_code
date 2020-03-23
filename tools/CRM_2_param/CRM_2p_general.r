require(rstan)

logistic_crm = stan_model(paste0(path_simus,"/tools/CRM_2_param/logistic.stan"))

########################
# Calculation of the next dose to administer from the data
calcul_next_dose = function(model, dose_donnees, wm, y, 
                            interv, target, target_min, target_max, dose_cur, saut, c_over, c_stop,
                            n_burn=1000, n_iter=5000, n_thin=1){
  n_pat = length(dose_donnees)
  nb_doses = length(wm)
  data_cur = list(n_pat=n_pat, nb_doses=nb_doses, y=y, dose_donnees=dose_donnees, wm=wm)
  dim(data_cur$y)=length(y)
  dim(data_cur$dose_donnees)=length(dose_donnees)
  init_cur1  = list(beta0=0, beta1=1)
  init_cur2  = list(beta0=rnorm(1,0,sqrt(10)), beta1=rexp(1,1))
  
  sample_beta = extract(sampling(model, data=data_cur, chains=2, init=list(init_cur1, init_cur2), 
                                 warmup=n_burn, iter=n_thin*n_iter+n_burn, thin=n_thin, refresh=0,
                                 control = list(adapt_delta = 0.99)), 
                        permuted=FALSE)
  comb_samp = rbind(sample_beta[,1,3:(3+nb_doses-1)], 
                    sample_beta[,2,3:(3+nb_doses-1)] 
  )
  nb_samp = nrow(comb_samp)
  if(interv==TRUE){
    proba_overdosing = numeric(nb_doses)
    proba_interv = numeric(nb_doses)
    for(j in 1:nb_samp){
      proba_interv = proba_interv + (comb_samp[j,] >= target_min & comb_samp[j,] <= target_max)
      proba_overdosing = proba_overdosing + (comb_samp[j,] > target_max)
    }
    proba_interv = proba_interv/nb_samp
    proba_overdosing = proba_overdosing/nb_samp
    ind_control = which(proba_overdosing < c_over)
    if(proba_overdosing[1] >= c_stop){
      next_dose = 0
    }
    else{
      if(length(ind_control)>0){
        next_dose = which.max(proba_interv[ind_control])
      }
      else{
        next_dose = 1
      }
    }
  }
  else{
    ptox = colMeans(comb_samp)
    next_dose = which.min(abs(ptox-target))
  }
  dose_cur = min(next_dose, dose_cur+saut)
  return(dose_cur)
}

# Calculation of the toxicity probabilities from the data
calcul_next_dose_pTox = function(model, dose_donnees, wm, y, interv, target, target_min, target_max, dose_cur, saut, c_over, c_stop,
                            n_burn=1000, n_iter=5000, n_thin=1){
  n_pat = length(dose_donnees)
  nb_doses = length(wm)
  data_cur = list(n_pat=n_pat, nb_doses=nb_doses, y=y, dose_donnees=dose_donnees, wm=wm)
  dim(data_cur$y)=length(y)
  dim(data_cur$dose_donnees)=length(dose_donnees)
  init_cur1  = list(beta0=0, beta1=1)
  init_cur2  = list(beta0=rnorm(1,0,sqrt(10)), beta1=rexp(1,1))
  sample_beta = extract(sampling(model, data=data_cur, chains=2, init=list(init_cur1, init_cur2), 
                                 warmup=n_burn, iter=n_thin*n_iter+n_burn, thin=n_thin, refresh=0,
                                 control = list(adapt_delta = 0.99)), 
                        permuted=FALSE)
  comb_samp = rbind(sample_beta[,1,3:(3+nb_doses-1)], 
                    sample_beta[,2,3:(3+nb_doses-1)] 
  )
  ptox = colMeans(comb_samp)
  nb_samp = nrow(comb_samp)
  if(interv==TRUE){
    proba_overdosing = numeric(nb_doses)
    proba_interv = numeric(nb_doses)
    for(j in 1:nb_samp){
      proba_interv = proba_interv + (comb_samp[j,] >= target_min & comb_samp[j,] <= target_max)
      proba_overdosing = proba_overdosing + (comb_samp[j,] > target_max)
    }
    proba_interv = proba_interv/nb_samp
    proba_overdosing = proba_overdosing/nb_samp
    ind_control = which(proba_overdosing < c_over)
    if(proba_overdosing[1] >= c_stop){
      next_dose = 0
    }
    else{
      if(length(ind_control)>0){
        next_dose = which.max(proba_interv[ind_control])
      }
      else{
        next_dose = 1
      }
    }
  }
  else{
    next_dose = which.min(abs(ptox-target))
  }
  dose_cur = min(next_dose, dose_cur+saut)
  
  res=list(dose=dose_cur,pTox=ptox)
  
  if(interv==TRUE){
    res=list(dose=dose_cur,pTox=ptox,pInterv=proba_interv,pOverdose=proba_overdosing)
  }
  
  return(res)
}



calcul_pTox = function(model, dose_donnees, wm, y, target,
                       n_burn=1000, n_iter=5000, n_thin=1){
  n_pat = length(dose_donnees)
  nb_doses = length(wm)
  data_cur = list(n_pat=n_pat, nb_doses=nb_doses, y=y, dose_donnees=dose_donnees, wm=wm)
  dim(data_cur$y)=length(y)
  dim(data_cur$dose_donnees)=length(dose_donnees)
  init_cur1  = list(beta0=0, beta1=1)
  init_cur2  = list(beta0=rnorm(1,0,sqrt(10)), beta1=rexp(1,1))
  sample_beta = extract(sampling(model, data=data_cur, chains=2, init=list(init_cur1, init_cur2), 
                                 warmup=n_burn, iter=n_thin*n_iter+n_burn, thin=n_thin, refresh=0,
                                 control = list(adapt_delta = 0.99)), 
                        permuted=FALSE)
  comb_samp = rbind(sample_beta[,1,3:(3+nb_doses-1)], 
                    sample_beta[,2,3:(3+nb_doses-1)] 
                    
  )
  
  ptox = colMeans(comb_samp)
  
  return(ptox)
}


########################
# Inclusion patients
incl_pat = function(n_pat, coh, dose_donnees, dose_cur, sc, y){
  n_pat = n_pat+coh
  dose_donnees = c(dose_donnees, rep(dose_cur,coh))
  sim = runif(coh)
  for(j in 1:coh){
    if(sim[j] <= sc[dose_cur]){
      y = c(y, 1)
    }
    else{
      y = c(y, 0)
    }
  }
  return(list("n_pat"=n_pat, "dose_donnees"=dose_donnees, "y"=y))
}


########################
# Simulation of a modified CRM
CRM_2p = function(model, nb_doses, wm, sc, interv, target, target_min, target_max, n_tot, coh_start, coh_next, 
                  saut, startup, c_over, c_stop, n_burn, n_iter, n_thin){
  dose_cur = 1
  dose_donnees = c()
  y = c()
  MTD = NA
  n_pat = 0
  
  if(startup == TRUE){
    while(any(y==1)==FALSE && n_pat < n_tot && dose_cur < nb_doses && dose_cur > 0){
      inc = incl_pat(n_pat, coh_start, dose_donnees, dose_cur, sc, y)
      n_pat=inc$n_pat
      dose_donnees=inc$dose_donnees
      y=inc$y
      dose_cur = calcul_next_dose(model, dose_donnees, wm, y, interv, target, target_min, target_max, dose_cur, 
                                  saut, c_over, c_stop, n_burn, n_iter, n_thin)
    }
  }
  while(n_pat+coh_next <= n_tot && dose_cur > 0){
    inc = incl_pat(n_pat, coh_next, dose_donnees, dose_cur, sc, y)
    n_pat=inc$n_pat
    dose_donnees=inc$dose_donnees
    y=inc$y
    dose_cur =  calcul_next_dose(model, dose_donnees, wm, y, interv, target, target_min, target_max, dose_cur, 
                                 saut, c_over, c_stop, n_burn, n_iter, n_thin)
  }
  MTD = dose_cur
  return(list("dose_donnees"=dose_donnees, "y"=y, "MTD"=MTD))
}



#######################
# Simulation of multiple modified CRM
simul_CRM_2p = function(model, nb_doses, wm, sc, interv, target, target_min, target_max, n_tot, coh_start, 
                        coh_next, saut, c_over, c_stop, startup, n_burn, n_iter, n_thin, nb_sim, seed){
  set.seed(seed)
  rec_dose = numeric(nb_doses)
  pat_dose = numeric(nb_doses)
  dlt_dose = numeric(nb_doses)
  for (sim in 1:nb_sim){
    if(sim %% 10 == 0){
      print(sim)
    }
    sim_i = CRM_2p(model, nb_doses, wm, sc, interv, target, target_min, target_max, n_tot, coh_start, coh_next, 
                   saut, startup, c_over, c_stop, n_burn, n_iter, n_thin)
    rec_dose[sim_i$MTD] = rec_dose[sim_i$MTD]+1
    dose_donnees = sim_i$dose_donnees
    doses = unique(dose_donnees)
    dlt = sim_i$y
    for(d in doses){
      ind_d = which(dose_donnees==d)
      pat_dose[d] = pat_dose[d]+length(ind_d)
      dlt_dose[d] = dlt_dose[d]+sum(dlt[ind_d])
    }
  }
  rec_dose = rec_dose/nb_sim*100
  pat_dose = pat_dose/nb_sim
  dlt_dose = dlt_dose/nb_sim
  return(list("rec_dose"=rec_dose, "pat_dose"=pat_dose, "dlt_dose"=dlt_dose))
}





