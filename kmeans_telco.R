
#Versión de R
version

#Instalando librerias


#Invocando librerias
library(readxl)
library(stringr)
library (sqldf)
library(openxlsx)
library(sjPlot)
library(agricolae)
library(graphics)
library(corrplot)
library(FactoMineR)
library(factoextra)
library(devtools)

memory.size(max = TRUE)
memory.limit(size=14000)
#---------------------------------------------------------------------#
#                    ANALISIS DE CORRESPONDENCIA                      #
#---------------------------------------------------------------------#

#Evaluación para clientes que han optenido un servicio TRIO y de procedencia peruana

#---Setear ruta del trabajo
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
getwd()


#---Importando base de datos
tablon <- read.csv("tablon.csv")
datos_personales <- read_excel("datos_personales.xlsx")
calificacion <- read_excel("calificacion_crediticia.xlsx")

#---Visualizacion de Tablas
head(tablon)
head(datos_personales)
head(calificacion)

#---Verificando el Tipo de datos
str(tablon)


#----------------------------------------------------------------------#
#                          LIMPIEZA DE DATOS                           #
#----------------------------------------------------------------------#

#Rellenando ceros faltantes a la izquierda de los DNI
tablon$DNI<-str_pad(tablon$DNI, 8, pad = "0")
datos_personales$dni<-str_pad(datos_personales$dni, 8, pad = "0")
calificacion$dni<-str_pad(calificacion$dni, 8, pad = "0")


#---Agregando al Tablon general variables de datos personales y calificacion crediticia

datos= sqldf("select a.*,b.genero,b.edad,b.estciv,c.calificacion from tablon a 
             inner join datos_personales b on a.dni=b.dni
             left join calificacion c on a.dni=c.dni")

head(datos)

#Valores faltantes - calificación crediticia
datos$calificacion[is.na(datos$calificacion)] <- "SIN DEFINCION"

#Limpieza de Valores de la variable desafiliación de las páginas blancas
datos$DESAFILIACION_PB <- str_to_upper(datos$DESAFILIACION_PB, locale = "es")
datos$DESAFILIACION_PB<-ifelse(datos$DESAFILIACION_PB=='NO APLICA',"NO",
                               ifelse(datos$DESAFILIACION_PB=='YA CUENTA',"SI",
                                      ifelse(nchar(datos$DESAFILIACION_PB)==0,"NO SABE","SI")))

#Homologando valores del Departamento
datos$DEPARTAMENTO <- str_to_upper(datos$DEPARTAMENTO, locale = "es")


#Valores faltantes - Adicional deco HD
datos$ADICIONAL_DECO_HD[is.na(datos$ADICIONAL_DECO_HD)] <- 0

#Valores faltantes - Adicional deco DVR
datos$ADICIONAL_DECO_DVR[is.na(datos$ADICIONAL_DECO_DVR)] <- 0

#Valores faltantes - Adicional deco SMART
datos$ADICIONAL_DECO_SMART[is.na(datos$ADICIONAL_DECO_SMART)] <- 0

#Extrayendo cantidad de DECO's en el Tipo de equipamiento
datos$DECO <-as.numeric(gsub("\\D", "", datos$TIPO_EQUIPAMIENTO_DECO)) 
datos$DECO[is.na(datos$DECO)] <- 0

#Extrayendo Mbps del servicio contratado
datos$MBPS <-as.numeric(gsub("\\D", "", datos$SUB_PRODUCTO)) 
datos$MBPS[is.na(datos$MBPS)] <- 0

#Imputando el valor del tiempo de atención y espera en base a la fecha de llegada y hora de llegada
datos$TIEMPO_ATENCION[is.na(datos$TIEMPO_ATENCION)] <- round(median(datos$TIEMPO_ATENCION, na.rm = TRUE))
datos$TIEMPO_ESPERA[is.na(datos$TIEMPO_ESPERA)] <- round(median(datos$TIEMPO_ESPERA, na.rm = TRUE))


#----------------------------------------------------------------------#
#                     PROCESAMIENTO TABLON MCA                         #
#----------------------------------------------------------------------#

#se tomará en cuenta el producto de primera adquisión en el periodo analizado
#ya que este el producto principal que llamó la atención al nuevo cliente


temp1= sqldf("select a.* from datos a 
             inner join (select DNI,min(codigo_pedido)codigo_pedido
             from datos where SUB_PRODUCTO like '%TRIO%' group by dni )b
             on (a.dni=b.dni and a.codigo_pedido=b.codigo_pedido)where SUB_PRODUCTO like '%TRIO%'")
head(temp1)


temp2= sqldf("select distinct a.DNI,a.EDAD,a.GENERO,a.ESTCIV,a.CALIFICACION,a.SUB_PRODUCTO,
             a.FECHA_DE_LLAMADA,
             case when a.CLIENTE_TIENE_EMAIL='SI' OR a.ENVIO_DE_CONTRATOS='EMAIL' THEN 'SI' ELSE 'NO' end as EMAIL ,
             a.DEPARTAMENTO,a.HORA_DE_LLAMADA,a.CANAL_DE_VENTA_AGRUPADA,a.TECNOLOGIA_DE_INTERNET,a.campana,a.DESAFILIACION_PB,
             a.MODALIDAD_DE_PAGO,a.REGION from temp1 a ")
head(temp2)

# verificando valores de documentos únicos
length(temp2$DNI) #34259
length(unique(temp2$DNI)) #34259

#----------------------------------------------------------------------#
#                     CREANDO NUEVAS VARIABLES                         #
#----------------------------------------------------------------------#

#1-Variable Dia de compra
temp2$DIA_COMPRA <- weekdays(as.Date(as.factor(temp2$FECHA_DE_LLAMADA), format = '%d/%m/%y'))


#2-Variable Turno
temp2$TURNO<-ifelse(as.integer(substr(temp2$HORA_DE_LLAMADA, 1,2))<6,"Madrugada",
                    ifelse(as.integer(substr(temp2$HORA_DE_LLAMADA, 1,2))<12,"Manana",
                           ifelse(as.integer(substr(temp2$HORA_DE_LLAMADA, 1,2))<18,"Tarde", "Noche")))

#3-Categoria acorde a la Edad
temp2$CAT_EDAD<-ifelse(as.integer(temp2$edad)<18,"Adolescente",
                       ifelse(as.integer(temp2$edad)<30,"Joven",
                              ifelse(as.integer(temp2$edad)<60,"Adulto", "Adulto Mayor")))

head(temp2,20)


#----------------------------------------------------------------------#
#                      MATRIZ FINAL SEGMENTACION                       #
#----------------------------------------------------------------------#


matriz_seg= sqldf("select distinct dni,count(codigo_pedido)cnt_trios,edad,
                  SUM(deco)nro_deco, sum(tiempo_atencion+tiempo_espera)/count(codigo_pedido) ind_tiempo_total,
                  SUM(monto)monto_mens_tot,MAX(MBPS)MAX_MBPS
                  from 
                  (select *, 
                  case 
                  when SUB_PRODUCTO='TRIO CONTROL 1 MBPS ESTANDAR DTH' then 119.9
                  when SUB_PRODUCTO='TRIO PLANO LOCAL 10 MBPS ESTANDAR DIGITAL' then 105
                  when SUB_PRODUCTO='TRIO PLANO LOCAL 2 MBPS ESTANDAR DIGITAL' then 129.9
                  when SUB_PRODUCTO='TRIO PLANO LOCAL 6 MBPS ESTANDAR DTH' then 149.9
                  when SUB_PRODUCTO='TRIO PLANO LOCAL 6 MBPS ESTANDAR DIGITAL' then 149.9
                  when SUB_PRODUCTO='TRIO PLANO LOCAL 12 MBPS ESTANDAR DIGITAL' then 159.9
                  when SUB_PRODUCTO='TRIO PLANO LOCAL 12 MBPS ESTANDAR DTH' then 159.9
                  when SUB_PRODUCTO='TRIO PLANO LOCAL 20 MBPS ESTANDAR DIGITAL' then 155
                  when SUB_PRODUCTO='TRIO PLANO LOCAL 20 MBPS ESTANDAR DTH' then 155
                  when SUB_PRODUCTO='TRIO PLANO LOCAL 40 MBPS ESTANDAR DIGITAL' then 165
                  when SUB_PRODUCTO='TRIO PLANO LOCAL 120 MBPS ESTANDAR DIGITAL' then 245
                  when SUB_PRODUCTO='TRIO PLANO LOCAL 80 MBPS ESTANDAR DIGITAL' then 249.9
                  when SUB_PRODUCTO='TRIO PLANO LOCAL 200 MBPS ESTANDAR DIGITAL' then 285
                  end as monto
                  from datos)
                  where SUB_PRODUCTO like '%TRIO%' group by dni,edad ")

head(matriz_seg,10)


# verificando valores de documentos únicos
length(matriz_seg$DNI) #34259
length(unique(matriz_seg$DNI)) #34259


#----------------------------------------------------------------------#
#                  ANALISIS EXPLORATORIO                               #
#----------------------------------------------------------------------#


#----- Variables Cuantitativas

# Variable: Edad
boxplot(matriz_seg$edad,main = "Distribución de Edades",xlab = "Edad", col = "deepskyblue4",
        border = "blue",horizontal = TRUE,notch = TRUE)
summary(matriz_seg$edad)

# Variable : Monto
h1<-hist(as.numeric(matriz_seg$monto_mens_tot),border=TRUE,
         main="Distribución de Montos Mensuales",xlab="Monto Total Mensual",col = "darkslategray1",pch = 20)
polygon.freq(h1,frequency=1,col="deepskyblue4")
summary(matriz_seg$monto_mens_tot)


# Variable : Cantidad de Servicios Trios
h1<-hist(as.numeric(matriz_seg$cnt_trios),border=TRUE,
         main="Distribución de Cantidad de Servicios Trios",xlab="Nro de Servicios Trios",col = "darkslategray1",pch = 20)
polygon.freq(h1,frequency=1,col="deepskyblue4")
summary(matriz_seg$cnt_trios)


# Variable: Indicador tiempo total (tiempo de atención + tiempo de espera)
boxplot(matriz_seg$ind_tiempo_total,main = "Distribución del Indicador Tiempo total/Nro Servicios",
        xlab = "Ind_Tiempo Total", col = "deepskyblue4",
        border = "blue",horizontal = TRUE,notch = TRUE)
summary(matriz_seg$ind_tiempo_total)


#Correlaciones entre las variables cuantitativas
chart.Correlation(matriz_seg[,2:6], histogram = T, pch =24)



for (i in 2:7) {
  plot(matriz_seg[,i], main=colnames(matriz_seg)[i],
       ylab = "Count", col="steelblue", las = 2)
}

boxplot(matriz_seg$cnt_trios, 
        ylab = "cnt_trios", 
        main="Boxplot de cnt_trios",
        col = "yellow")




# FILTROS PARA DETERMINAR SEGMENTOS DE ANALISIS

#descal <- matriz_seg
descal <- sqldf("select * from matriz_seg limit 10000")

rownames(descal) <- descal[,1]

descal<-scale(descal[c(3,4,5,6,7)])


library(moments)
kurtosis(descal)

# Analisis de Correlacion
###########################
library(corrplot)

#corrplot(M, method = "circle")
corrplot(cor(descal) , method = "number")

library(DMwR)
library(factoextra)
library(clustertend)
library(seriation)


# Evaluando al Tendencia de los Clusters
########################################
# Calculando Hopkins statistic 
set.seed(12)
hopkins(descal, n = nrow(descal)-1)



# Graficando el VAT 
fviz_dist(dist(descal), show_labels = FALSE)+
  labs(title = "CON PDT")
#Color en morado y rosado 

#Dendogramas
###################
d <- dist(descal, method = "euclidean") # distancia euclidea
fit <- hclust(d, method="ward.D2") # metodo de enlace
str(fit)

# Dendograma
plot(fit)
plot(fit,hang=-1) # -1 PARA ALINEADO

rect.hclust(fit, k=4, border="blue")

#windows()
# Genera clusters a una distancia de 25
cut<-cutree(fit,h=4) # Te indica que elemento pertence a que grupo
cut

write.csv(cut,file = "23102018/Dendograma_5.csv")



#Evaluando numero de Clusters
#############################
#### 1 #### K-MEANS
library(factoextra)
set.seed(123)
fviz_nbclust(descal, kmeans, method = "wss") +
  geom_vline(xintercept = 4, linetype = 2) +
  labs(subtitle = "Elbow method K-MEANS")
#Corte optimo 4

#### 1 #### PAM
library(factoextra)
set.seed(123)
fviz_nbclust(descal, pam, method = "wss") +
  geom_vline(xintercept = 4, linetype = 2) +
  labs(subtitle = "Elbow method PAM")
#Corte optimo 4



#### 2 #### K-MEANS
fviz_nbclust(descal, kmeans, method = "silhouette") + #grafico de siluet el maximo 2 
  geom_vline(xintercept = 4, linetype = 2) +
  labs(subtitle = "silhouette K-MEANS")
# 2 o 4

#### 2 #### PAM
fviz_nbclust(descal, pam, method = "silhouette") + #grafico de siluet el maximo 2 
  geom_vline(xintercept = 4, linetype = 2) +
  labs(subtitle = "silhouette PAM")
# 2 o 4


#### 3 #### K-MEANS
fviz_nbclust(descal, kmeans, method = "gap_stat")+
  labs(subtitle = "gap_stat K-MEANS")

#### 3 #### PAM
fviz_nbclust(descal, pam, method = "gap_stat")+
  labs(subtitle = "gap_stat PAM")



#### 4 GRAFICO DE SILUETA #### k-MEANS
set.seed(128)
centers=3
km <- kmeans(descal, centers, nstart = 10)

library("cluster")
sil <- silhouette(km$cluster, dist(descal,method="euclidean"))
sil

plot(sil, main ="Silhouette plot - K-means")
fviz_silhouette(sil)


#### 4 GRAFICO DE SILUETA #### PAM
set.seed(129)
k=4
cluster_pam <- pam(descal,k)
plot(silhouette(cluster_pam))
silhouette_pam<-silhouette(cluster_pam)

# QUITAR VALOIRES NEATIVOS

#lista=row.names(silhouette_pam)[1:3]

contador=0
primer_elemento=TRUE
#row.names(silhouette_pam)[477]
arreglo=dim(silhouette_pam)[1]
arreglo
lista_silhouette_pam=0
for (i in 1:arreglo) {
  if(silhouette_pam[i,3]>0)
  {
    if(primer_elemento==TRUE)
    {
      lista_silhouette_pam=row.names(silhouette_pam)[i]
      primer_elemento=FALSE
    }else{
      lista_silhouette_pam=append(lista_silhouette_pam,row.names(silhouette_pam)[i])
    }
    print(silhouette_pam[i,3])
    contador=contador+1
  }
}
print(contador)
lista_silhouette_pam
descal <- descal[lista_silhouette_pam,] 
datos2 <- datos2[lista_silhouette_pam,]
#descal_pam2 <- descal_pam[lista_silhouette_pam,] 

#descal<-descal_pam2

write.csv(silhouette(cluster_pam),file = "18102018/silhouette_pam_4.csv")


write.csv(datos,file = "23102018/datos_22.csv")

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##
#### CLUSTER K-MEANS #################################################################
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##


library(NbClust)
set.seed(123)

res.nbclust <- NbClust(descal, distance = "euclidean",
                       min.nc = 3, max.nc = 8, 
                       method = "ward.D2", index ="all")
write.csv(res.nbclust$Best.partition,file = "salida_euclidean_121018_3.csv")


#res.nbclust <- NbClust(descal, distance = "manhattan",
#                       min.nc = 2, max.nc = 8, 
#                       method = "ward.D2", index ="all")
#write.csv(res.nbclust$Best.partition,file = "salida_manhattan.csv")


#res.nbclust <- NbClust(descal, distance = "minkowski",
#                       min.nc = 2, max.nc = 8, 
#                       method = "ward.D2", index ="all")
#write.csv(res.nbclust$Best.partition,file = "salida_minkowski.csv")

set.seed(128)
centers=5
km <- kmeans(descal, centers, nstart = 10)

library("cluster")
sil <- silhouette(km$cluster, dist(descal,method="euclidean"))
sil

plot(sil, main ="Silhouette plot - K-means")
fviz_silhouette(sil)

# GRAFICOS
#############################

clusplot(descal,km$cluster, color = TRUE,
         shade = TRUE,lines=0,
         main ="Gráfico de Conglomerados")

plot(descal,col=c("green","red","blue","black")[km$cluster],pch=16)

# K-MEANS PERFILADO Y CARACTERISTICAS DEL CLUSTER 
####################################################

# Adicionar los cluster a la base de datos
descal.new<-cbind(datos2,km$cluster)
descal.new

colnames(descal.new)<-c(colnames(descal.new[,-length(descal.new)]), "cluster.km")
head(descal.new)

descal.new[,1:4]

# Tabla de medias
med<-aggregate(x = descal.new[,1:4],by = list(descal.new$cluster.km),FUN = mean)
med

# Describir variables
par(mfrow=c(1,4))
for (i in 1:length(descal.new[,1:4])) {
  boxplot(descal.new[,i]~descal.new$cluster.km, main=names(descal.new[i]), type="l",col = "yellow")
}
par(mfrow=c(1,1))

write.csv(km$cluster,file = "23102018/salida_K-MEANS_5.csv")


#########################################################
#  PAM                                                  #
#########################################################

set.seed(129)
k=4
#cluster_pam <- pam(descal,k)
#cluster_pam <- pam(scale(datos),k)
cluster_pam <- pam(descal,k)


plot(cluster_pam)
silhouette(cluster_pam)
plot(silhouette(cluster_pam))

library(fpc)
plotcluster(descal,cluster_pam$clustering)

#write.csv(cluster_pam$clustering,file = "salida_PAM_3_1.csv")



# GRAFICOS
#############################

clusplot(descal,cluster_pam$clustering, color = TRUE,
         shade = TRUE,lines=0,
         main ="CLUSTER PAM - Gráfico de Conglomerados")

plot(descal,col=c("yellow","green","red","blue","black","purple","orange")[cluster_pam$clustering],pch=16)


# PAM PERFILADO Y CARACTERISTICAS DEL CLUSTER 
####################################################

# Adicionar los cluster a la base de datos
#datos<-datos[lista_silhouette_pam,] 
descal2.new<-cbind(datos2,cluster_pam$clustering)
#descal2.new<-cbind(datos[c(-1,-2,-9)],cluster_pam$clustering)
#descal2.new<-cbind(datos,cluster_pam$clustering)
descal2.new

colnames(descal2.new)<-c(colnames(descal2.new[,-length(descal2.new)]), "cluster_PAM")
head(descal2.new)

descal2.new[,1:4]

# Tabla de medias
med2<-aggregate(x = descal2.new[,1:4],by = list(descal2.new$cluster_PAM),FUN = mean)
med2

# Describir variables
par(mfrow=c(2,4))
for (i in 1:length(descal2.new[,1:4])) {
  boxplot(descal2.new[,i]~descal2.new$cluster_PAM, 
          main=names(descal2.new[i]), 
          type="l",
          col = "yellow")
}
par(mfrow=c(1,1))


write.csv(cluster_pam$clustering,file = "23102018/salida_PAM_4.csv")











#########################################################
#  CLARA                                                  #
#########################################################

cluster_clara=clara(descal,3)
cluster_clara
plot(cluster_clara)

plot(silhouette(cluster_clara))
##### Valor Average Silhouette width: 0.35 ####




##### VALIDAR #####
#-----------------------------------------#
# Perfilado y caracterización de clusters #
#-----------------------------------------#

# Adicionar los cluster a la base de datos
distritos.new<-cbind(distritos,res$cluster)
colnames(distritos.new)<-c(colnames(distritos.new[,-length(distritos.new)]), "cluster.km")
head(distritos.new)

# Tabla de medias
med<-aggregate(x = distritos.new[,1:7],by = list(distritos.new$cluster.km),FUN = mean)
med

# Describir variables
par(mfrow=c(2,4))
for (i in 1:length(distritos.new[,1:7])) {
  boxplot(distritos.new[,i]~distritos.new$cluster.km, main=names(distritos.new[i]), type="l")
}
par(mfrow=c(1,1))
##### POR VALIDAR #####













#########################################################
#  FANNY                                                #
#########################################################
library(cluster)
fanny_cluster=fanny(descal,3)
fanny_cluster
plot(fanny_cluster)
plot(silhouette(fanny_cluster))

##### Valor Average Silhouette width: 0.31 ####






































