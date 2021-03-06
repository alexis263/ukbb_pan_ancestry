library(tidyverse)
library(RColorBrewer)
library(maptools)
library(cowplot)

setwd('/Users/alicia/daly_lab/ukbb_diverse_pops/pca')

pop_assign <- read_delim(gzfile('globalref_ukbb_pca_pops_rf_50.txt.gz'), delim='\t') %>%
  select(s, pop)
ethnicity <- read_tsv('../data/ukb31063.ethnicity_birth.txt')
ethnicity_ancestry <- pop_assign %>%
  left_join(ethnicity, by=c('s'='userId'))
table(ethnicity_ancestry$continent, ethnicity_ancestry$pop)
as.data.frame(table(ethnicity_ancestry$country, ethnicity_ancestry$pop)) %>% 
  subset(Var2=='AFR') %>%
  arrange(desc(Freq)) %>%
  head(10)

# Plot location maps ------------------------------------------------------

data(wrld_simpl)
world <- fortify(wrld_simpl)

# Read the latitude/longitdue/plotting data for reference populations
pop_pos <- read.csv('../data/pop_plot_info.csv', header=T)

plot_cont_map <- function(cont_name, lon_lim, lat_lim, rand_col=FALSE) {
  pop_pos_plot <- subset(pop_pos, Continent == cont_name)
  pop_pos_plot$Population <- factor(pop_pos_plot$Population, levels=as.character(pop_pos_plot$Population))
  if(rand_col) {
    color_vec <- colorRampPalette(brewer.pal(4, 'Spectral'))(length(pop_pos_plot$Population))
  }
  else {
    color_vec <- as.character(pop_pos_plot$Color)
  }
  shape_vec <- rep_len(c(21:25), length.out = length(color_vec))
  names(color_vec) <- pop_pos_plot$Population
  names(shape_vec) <- pop_pos_plot$Population
  
  # plot the map of Africa with data points labeled
  p_map <- ggplot() +
    geom_polygon(data = world, aes(long, lat, group=group), fill='lightyellow', color='lightgrey') +
    geom_point(data = pop_pos_plot, aes(Longitude, Latitude, color=Population, fill=Population, shape=Population), size=3) +
    coord_fixed(xlim = lon_lim, ylim = lat_lim) +
    labs(x='Longitude', y='Latitude') +
    theme_classic() +
    scale_fill_manual(name = "Population",
                      values = color_vec) +
    scale_color_manual(name = "Population",
                       values = color_vec) +
    scale_shape_manual(name = "Population",
                       values = shape_vec) +
    theme(panel.background = element_rect(fill = "lightblue"),
          plot.background = element_rect(fill = "transparent", color = NA),
          #legend.position='bottom',
          text = element_text(size=16),
          axis.text = element_text(color='black'))
  return(list(p_map, color_vec, shape_vec))
}

afr <- plot_cont_map('AFR', c(-20,50), c(-35,35))
amr <- plot_cont_map('AMR', c(-140,-35), c(-50,65), rand_col=TRUE)
csa <- plot_cont_map('CSA', c(60,95), c(5,45), rand_col=TRUE)
eas <- plot_cont_map('EAS', c(78,148), c(0,70), rand_col=TRUE)
mid <- plot_cont_map('MID', c(0,60), c(10,50), rand_col=TRUE)

ggsave('afr_ref_map.pdf', afr[[1]])
ggsave('csa_ref_map.pdf', csa[[1]])
ggsave('eas_ref_map.pdf', eas[[1]])
ggsave('mid_ref_map.pdf', mid[[1]])
ggsave('amr_ref_map.pdf', amr[[1]])
p2 <- p1 + guides(fill=F, color=F, shape=F)


# Load population PCA and covariate info ----------------------------------

# NOTE: change order here to correspond to order in color_vec
load_ref_pcs <- function(ref_pcs, ref_fam, pop_color) {
  ref_pcs <- read_delim(gzfile(ref_pcs), delim='\t')
  fam <- read.table(ref_fam, col.names=c('pop', 's', 'dad', 'mom', 'sex', 'pheno'))  %>%
    select(pop, s, sex)
  ref_data <- merge(ref_pcs, fam, by='s')
  ref_data$pop <- factor(ref_data$pop, levels = names(pop_color))
  return(ref_data)
}

ref_afr <- load_ref_pcs('AFR_HGDP_1kG_AGVP_maf005_geno05_unrel_ukbb_scores.txt.bgz', 'AFR_HGDP_1kG_AGVP_maf005_geno05_unrel.fam', afr[[2]])
ref_csa <- load_ref_pcs('CSA_HGDP_1kG_maf005_geno05_unrel_ukbb_scores.txt.bgz', 'CSA_HGDP_1kG_maf005_geno05_unrel.fam', csa[[2]])
ref_eas <- load_ref_pcs('EAS_HGDP_1kG_maf005_geno05_unrel_ukbb_scores.txt.bgz', 'EAS_HGDP_1kG_maf005_geno05_unrel.fam', eas[[2]])
ref_mid <- load_ref_pcs('MID_HGDP_1kG_maf005_geno05_unrel_ukbb_scores.txt.bgz', 'MID_HGDP_1kG_maf005_geno05_unrel.fam', mid[[2]])

# Load UKB population data ------------------------------------------------

load_ukb <- function(cont_name, filename) {
  ukb_pop <- read_delim(gzfile(filename), delim='\t') %>%
    left_join(pop_assign) %>%
    filter(pop==cont_name) %>%
    left_join(ethnicity, by=c('s'='userId')) #####
}
ukb_afr <- load_ukb('AFR', 'ukbb_AFR_HGDP_1kG_AGVP_maf005_geno05_unrel_scores.txt.bgz')
ukb_csa <- load_ukb('CSA', 'ukbb_CSA_HGDP_1kG_maf005_geno05_unrel_scores.txt.bgz')
ukb_eas <- load_ukb('EAS', 'ukbb_EAS_HGDP_1kG_maf005_geno05_unrel_scores.txt.bgz')
ukb_mid <- load_ukb('MID', 'ukbb_MID_HGDP_1kG_maf005_geno05_unrel_scores.txt.bgz')
ukb_amr <- load_ukb('AMR', 'ukbb_AMR_HGDP_1kG_maf005_geno05_unrel_scores.txt.bgz')

#ukb_afr %>% dplyr::count(country) %>% arrange(desc(n)) %>% head(11)


# Plot PCA ----------------------------------------------------------------

p_afr <- ggplot(afr, aes(x=PC1, y=PC2, color=pop)) +
  geom_point(data=ukb_afr, color='grey') +
  geom_point() +
  scale_color_manual(values=color_vec, name='Population') +
  theme_classic() +
  theme(text = element_text(size=16))

ggsave('afr_cont_projection.pdf', p_afr, width=8, height=6)

plot_pca_ref_ukb <- function(ref_pop, ukb_pop, pop_color, pop_shape, first_pc='PC1', second_pc='PC2') {
  pca_pop <- ggplot(ref_pop, aes_string(x=first_pc, y=second_pc, color='pop', fill='pop', shape='pop')) +
    geom_point(data=ukb_pop, color='grey', fill='grey', shape=21) +
    geom_point() +
    scale_color_manual(values=pop_color, name='Population') +
    scale_fill_manual(values=pop_color, name='Population') +
    scale_shape_manual(values=pop_shape, name='Population') +
    guides(color=F, fill=F, shape=F) +
    theme_classic() +
    theme(text = element_text(size=12))
  
  x_lim <- ggplot_build(pca_pop)$layout$panel_scales_x[[1]]$range$range
  y_lim <- ggplot_build(pca_pop)$layout$panel_scales_y[[1]]$range$range
  pca_density <- ggplot(ukb_pop, aes_string(x=first_pc, y=second_pc)) +
    geom_hex(bins=50) +
    scale_fill_gradientn(trans='sqrt', name='Count',
                         colours = rev(brewer.pal(5,'Spectral'))) +
    lims(x=x_lim, y=y_lim) +
    theme_classic() +
    theme(text = element_text(size=12))
  
  return(list(pca_pop, pca_density))
}

save_plot <- function(pop, pop_name, ref_pop, ukb_pop) {
  p_pop_1_2 <- plot_pca_ref_ukb(ref_pop, ukb_pop, pop[[2]], pop[[3]], 'PC1', 'PC2')
  p_pop_3_4 <- plot_pca_ref_ukb(ref_pop, ukb_pop, pop[[2]], pop[[3]], 'PC3', 'PC4')
  p_pop_5_6 <- plot_pca_ref_ukb(ref_pop, ukb_pop, pop[[2]], pop[[3]], 'PC5', 'PC6')
  my_plot=plot_grid(p_pop_1_2[[1]], p_pop_1_2[[2]], rel_widths=c(1, 1.15))
  save_plot(pop_name, my_plot)
  save_plot(filename=paste0(pop_name, '_cont_projection_1_2.png'), plot=my_plot, base_height = 5, base_width=10)
  save_plot(paste0(pop_name, '_cont_projection_3_4.png'), plot_grid(p_pop_3_4[[1]], p_pop_3_4[[2]], rel_widths=c(1, 1.15)), base_height = 5, base_width=10)
  save_plot(paste0(pop_name, '_cont_projection_5_6.png'), plot_grid(p_pop_5_6[[1]], p_pop_5_6[[2]], rel_widths=c(1, 1.15)), base_height = 5, base_width=10)
}

save_plot(afr, 'afr', ref_afr, ukb_afr)
save_plot(csa, 'csa', ref_csa, ukb_csa)
save_plot(eas, 'eas', ref_eas, ukb_eas)
save_plot(mid, 'mid', ref_mid, ukb_mid)
p_afr_1_2 <- plot_pca_ref_ukb(ref_afr, ukb_afr, afr[[2]], afr[[3]], 'PC1', 'PC2')
p_afr_3_4 <- plot_pca_ref_ukb(ref_afr, ukb_afr, afr[[2]], afr[[3]], 'PC3', 'PC4')
p_afr_5_6 <- plot_pca_ref_ukb(ref_afr, ukb_afr, afr[[2]], afr[[3]], 'PC5', 'PC6')
save_plot('afr_cont_projection_1_2.png', plot_grid(p_afr_1_2[[1]], p_afr_1_2[[2]], rel_widths=c(1, 1.15)), base_height = 5, base_width=10)
save_plot('afr_cont_projection_3_4.png', plot_grid(p_afr_3_4[[1]], p_afr_3_4[[2]], rel_widths=c(1, 1.15)), base_height = 5, base_width=10)
save_plot('afr_cont_projection_5_6.png', plot_grid(p_afr_5_6[[1]], p_afr_5_6[[2]], rel_widths=c(1, 1.15)), base_height = 5, base_width=10)

p_csa_1_2 <- plot_pca_ref_ukb(ref_csa, ukb_csa, csa[[2]], csa[[3]], 'PC1', 'PC2')
p_csa_3_4 <- plot_pca_ref_ukb(ref_csa, ukb_csa, csa[[2]], csa[[3]], 'PC3', 'PC4')
p_csa_5_6 <- plot_pca_ref_ukb(ref_csa, ukb_csa, csa[[2]], csa[[3]], 'PC5', 'PC6')
save_plot('csa_cont_projection_1_2.png', plot_grid(p_csa_1_2[[1]], p_csa_1_2[[2]], rel_widths=c(1, 1.15)), base_height = 5, base_width=10)
save_plot('csa_cont_projection_3_4.png', plot_grid(p_csa_3_4[[1]], p_csa_3_4[[2]], rel_widths=c(1, 1.15)), base_height = 5, base_width=10)
save_plot('csa_cont_projection_5_6.png', plot_grid(p_csa_5_6[[1]], p_csa_5_6[[2]], rel_widths=c(1, 1.15)), base_height = 5, base_width=10)

p_eas_1_2 <- plot_pca_ref_ukb(ref_eas, ukb_eas, eas[[2]], eas[[3]], 'PC1', 'PC2')
p_eas_3_4 <- plot_pca_ref_ukb(ref_eas, ukb_eas, eas[[2]], eas[[3]], 'PC3', 'PC4')
p_eas_5_6 <- plot_pca_ref_ukb(ref_eas, ukb_eas, eas[[2]], eas[[3]], 'PC5', 'PC6')
save_plot('eas_cont_projection_1_2.png', plot_grid(p_eas_1_2[[1]], p_eas_1_2[[2]], rel_widths=c(1, 1.15)), base_height = 5, base_width=10)
save_plot('eas_cont_projection_3_4.png', plot_grid(p_eas_3_4[[1]], p_eas_3_4[[2]], rel_widths=c(1, 1.15)), base_height = 5, base_width=10)
save_plot('eas_cont_projection_5_6.png', plot_grid(p_eas_5_6[[1]], p_eas_5_6[[2]], rel_widths=c(1, 1.15)), base_height = 5, base_width=10)

p_mid_1_2 <- plot_pca_ref_ukb(ref_mid, ukb_mid, mid[[2]], mid[[3]], 'PC1', 'PC2')
p_mid_3_4 <- plot_pca_ref_ukb(ref_mid, ukb_mid, mid[[2]], mid[[3]], 'PC3', 'PC4')
p_mid_5_6 <- plot_pca_ref_ukb(ref_mid, ukb_mid, mid[[2]], mid[[3]], 'PC5', 'PC6')
save_plot('mid_cont_projection_1_2.png', plot_grid(p_mid_1_2[[1]], p_mid_1_2[[2]], rel_widths=c(1, 1.15)), base_height = 5, base_width=10)
save_plot('mid_cont_projection_3_4.png', plot_grid(p_mid_3_4[[1]], p_mid_3_4[[2]], rel_widths=c(1, 1.15)), base_height = 5, base_width=10)
save_plot('mid_cont_projection_5_6.png', plot_grid(p_mid_5_6[[1]], p_mid_5_6[[2]], rel_widths=c(1, 1.15)), base_height = 5, base_width=10)


# Within pop PCA (no ref) -------------------------------------------------

setwd('/Users/alicia/daly_lab/ukbb_diverse_pops/pca/ukb_within_continent')

read_pca <- function(pop_name, rel_unrel) {
  if(rel_unrel == 'rel') {
    pca <- read.table(gzfile(paste0(pop_name, '_rel_scores.txt.bgz')), header=T) %>%
      mutate(pop=pop_name, rel=rel_unrel)
  } else {
    pca <- read.table(gzfile(paste0(pop_name, '_scores.txt.bgz')), header=T) %>%
      mutate(pop=pop_name, rel=rel_unrel)
  }
  return(pca)
}

pops <- c('AFR', 'AMR', 'CSA', 'MID', 'EAS', 'EUR')

age_sex <- read.table(gzfile('uk_round2_allSamples_phenos_phesant.6148_5.tsv.gz'), header=T, sep='\t') %>%
  select(userId, age, sex)

bind_rels <- function(pop) {
  pop_rel <- read_pca(pop, 'rel')
  pop_unrel <- read_pca(pop, 'unrel')
  pop_bind <- pop_rel %>% bind_rows(pop_unrel)
}

afr <- bind_rels('AFR')
amr <- bind_rels('AMR')
csa <- bind_rels('CSA')
mid <- bind_rels('MID')
eas <- bind_rels('EAS')
eur <- bind_rels('EUR')

bind_pops <- afr %>%
  bind_rows(amr) %>%
  bind_rows(csa) %>%
  bind_rows(mid) %>%
  bind_rows(eas) %>%
  bind_rows(eur) %>%
  left_join(age_sex, by=c('s'='userId')) %>%
  mutate(age2 = age^2, age_sex = age*sex, age2_sex = age^2 * sex)

write.table(bind_pops, 'within_pop_pc_covs.txt', quote=F, row.names=F, sep='\t')

plot_pca_density <- function(dataset, first_pc, second_pc) {
  pc_biplot <- ggplot(dataset, aes_string(x=first_pc, y=second_pc)) +
    geom_hex(bins=50) +
    scale_fill_gradientn(trans = "log", breaks=c(1,20,400,8000,163000), name='Count',
                         colours = rev(brewer.pal(5,'Spectral'))) +
    theme_classic()
  return(pc_biplot)
}

pop_ellipse <- function(df, num_ellipses) {
  # get mean and SD of each PC among each pop
  pc_nams <- paste("PC",1:10,sep="")
  mean_pcs <- colMeans(df[,pc_nams])
  sd_pcs <- apply(df[,pc_nams],2,sd)
  # compute centroid distance for each individual
  centroid_dist <- rep(0,nrow(df))
  for(i in 1:num_ellipses) {
    centroid_dist <- centroid_dist + (df[,pc_nams[i]]-mean_pcs[i])^2/(sd_pcs[i]^2)
  }
  pop_dist <- df %>%
    mutate(centroid_dist=centroid_dist)
  return(pop_dist)
}

pop_centroid <- function(ind_dist, cutpoint0, cutpoint1) {
  pop_cut <- subset(ind_dist, centroid_dist < cutpoint0)
  p_centroid <- ggplot(pop_cut, aes(x=centroid_dist)) + 
    geom_histogram(bins=50) + 
    labs(title=paste0('Sample size: ', nrow(subset(ind_dist, centroid_dist < cutpoint0)), ' -> ', nrow(subset(ind_dist, centroid_dist < cutpoint1)))) + 
    geom_vline(xintercept=cutpoint1) +
    theme_bw()
  return(list(p=p_centroid, pop_cut=pop_cut))
}

save_filt_plots <- function(pop_name, pop_dist, cutpoint0, cutpoint1) {
  p_centroid0 = pop_centroid(pop_dist, cutpoint0, cutpoint1)
  ggsave(paste0(pop_name, '_within_pop_centroid_nofilt.pdf'), p_centroid0$p, height=7, width=7)
  p2 <- plot_pca_density(subset(pop_dist, centroid_dist < cutpoint0), 'PC1', 'PC2')
  ggsave(paste0(pop_name, '_within_pop_nofilt_pc1_2.png'), p2)
  p3 <- plot_pca_density(subset(pop_dist, centroid_dist < cutpoint0), 'PC3', 'PC4')
  ggsave(paste0(pop_name, '_within_pop_nofilt_pc3_4.png'), p3)
  p4 <- plot_pca_density(subset(pop_dist, centroid_dist < cutpoint0), 'PC5', 'PC6')
  ggsave(paste0(pop_name, '_within_pop_nofilt_pc5_6.png'), p4)
  p_centroid1 = pop_centroid(pop_dist, cutpoint1, cutpoint1)
  ggsave(paste0(pop_name, '_within_pop_centroid_filt.pdf'), p_centroid1$p, height=7, width=7)
  p6 <- plot_pca_density(subset(pop_dist, centroid_dist < cutpoint1), 'PC1', 'PC2')
  ggsave(paste0(pop_name, '_within_pop_filt_pc1_2.png'), p6)
  p7 <- plot_pca_density(subset(pop_dist, centroid_dist < cutpoint1), 'PC3', 'PC4')
  ggsave(paste0(pop_name, '_within_pop_filt_pc3_4.png'), p7)
  p8 <- plot_pca_density(subset(pop_dist, centroid_dist < cutpoint1), 'PC5', 'PC6')
  ggsave(paste0(pop_name, '_within_pop_filt_pc5_6.png'), p8)
  my_plot=plot_grid(p_centroid0$p, p2, p3, p4, p_centroid1$p, p6, p7, p8, nrow=2)
  save_plot(paste0(pop_name, '_within_pop.pdf'), my_plot, base_height=10, base_width = 18)
  return(p_centroid1$pop_cut)
}

csa_cut <- save_filt_plots('csa', csa_dist <- pop_ellipse(csa, 3), 1000, 3) #3, 3
afr_cut <- save_filt_plots('afr', afr_dist <- pop_ellipse(afr, 3), 1000, 2)
eas_cut <- save_filt_plots('eas', eas_dist <- pop_ellipse(eas, 3), 1000, 7.5)
amr_cut <- save_filt_plots('amr', amr_dist <- pop_ellipse(amr, 3), 1000, 4.8)
mid_cut <- save_filt_plots('mid', mid_dist <- pop_ellipse(mid, 5), 1000, 15)
eur_cut <- save_filt_plots('eur', eur_dist <- pop_ellipse(eur, 5), 1000, 10)


pop_cuts <- csa_cut %>%
  bind_rows(afr_cut, eas_cut, amr_cut, mid_cut, eur_cut) %>%
  select(s, pop)

write.table(pop_cuts, 'ukb_diverse_pops_pruned.tsv', row.names=F, sep='\t', quote=F)

