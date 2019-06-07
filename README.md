# Clustering en Scala
#### Importar librerias
```javascript
// crear Schema
import org.apache.spark.sql.types._
// crear ID incremental
import org.apache.spark.sql.functions._
```

#### Crear schema
```javascript
var schema = StructType(Array(
    StructField("sepal_length", DoubleType, true),
    StructField("sepal_width", DoubleType, true),
    StructField("petal_length", DoubleType, true),
    StructField("petal_width", DoubleType, true),
    StructField("label", StringType, true)))
```

#### Importar datos
```javascript
var dataset = spark.read.format("csv").
option("header", "true").
option("delimiter",";").
schema(schema).
load("iris_v2.csv").
select("sepal_length","sepal_width","petal_length","petal_width", "label")
```
#### Conteo de la data importada
```javascript
dataset.groupBy("label").count().show()
+---------------+-----+ 
|          label|count| 
+---------------+-----+ 
| Iris-virginica|   50| 
|    Iris-setosa|   50| 
|Iris-versicolor|   50| 
+---------------+-----+
```
#### Tipo de datos
```javascript
dataset.printSchema()
root 
|-- sepal_length: double (nullable = true) 
|-- sepal_width: double (nullable = true) 
|-- petal_length: double (nullable = true) 
|-- petal_width: double (nullable = true) 
|-- label: string (nullable = true)
```


##  Modelo
###  VectorAssembler
#### Importar librerias
```javascript
import org.apache.spark.ml.feature.VectorAssembler
import org.apache.spark.ml.linalg.Vectors
```
#### Seleccionar variables para el vector assembler
```javascript
val assembler = new VectorAssembler().
setInputCols(Array("sepal_length", "sepal_width", "petal_length", "petal_width")).
setOutputCol("features")

val output = assembler.transform(dataset)
```
#### validar resultados vector assembler
```javascript
output.show(2)
+------------+-----------+------------+-----------+-----------+-----------------+ 
|sepal_length|sepal_width|petal_length|petal_width|      label|         features| 
+------------+-----------+------------+-----------+-----------+-----------------+ 
|         5.1| 	      3.5|         1.4|        0.2|Iris-setosa|[5.1,3.5,1.4,0.2]| 
|         4.9|        3.0|         1.4|        0.2|Iris-setosa|[4.9,3.0,1.4,0.2]| 
+------------+-----------+------------+-----------+-----------+-----------------+
```

##  Basic Statistics
#### Descriptivos
```javascript
output.
select("sepal_length","sepal_width","petal_length","petal_width").
describe().show()
+-------+------------------+-------------------+------------------+------------------+ 
|summary|      sepal_length|        sepal_width|      petal_length|       petal_width| 
+-------+------------------+-------------------+------------------+------------------+ 
|  count|               150|                150|               150|               150| 
|   mean| 5.843333333333335| 3.0540000000000007|3.7586666666666693|1.1986666666666672| 
| stddev|0.8280661279778637|0.43359431136217375| 1.764420419952262|0.7631607417008414|
|    min|               4.3|                2.0|               1.0|               0.1| 
|    max|               7.9|                4.4|               6.9|               2.5|
+-------+------------------+-------------------+------------------+------------------+
```

####  Percentiles
```javascript
output.stat.approxQuantile("sepal_length",Array(0.25,0.5,0.75),0.0)
output.stat.approxQuantile("sepal_width",Array(0.25,0.5,0.75),0.0)
output.stat.approxQuantile("petal_length",Array(0.25,0.5,0.75),0.0)
output.stat.approxQuantile("petal_width",Array(0.25,0.5,0.75),0.0)
```
## Correlation
#### Importar Librerias
```javascript
import org.apache.spark.ml.linalg.{Matrix, Vectors}
import org.apache.spark.ml.stat.Correlation
import org.apache.spark.sql.Row
```

#### Pearson correlation matrix
```javascript
println(s"Pearson correlation matrix")
val Row(coeff1: Matrix) = Correlation.corr(output.select("features"), "features").head
//println(s"Pearson correlation matrix:\n $coeff1")

coeff1: org.apache.spark.ml.linalg.Matrix = 
1.0                   -0.10936924995062468  0.8717541573048866    0.8179536333691776
-0.10936924995062468  1.0                   -0.42051609640115817  -0.35654408961379946
0.8717541573048866    -0.42051609640115817  1.0                   0.9627570970509658
0.8179536333691776    -0.35654408961379946  0.9627570970509658    1.0
```
## MinMaxScaler
#### Importar librerías
```javascript
import org.apache.spark.ml.feature.MinMaxScaler
import org.apache.spark.ml.linalg.Vectors
```

#### MinMaxScaler
```javascript
val df_tmp = output

val scaler = new MinMaxScaler().setInputCol("features").setOutputCol("MinMaxScalerFeatures")

// Compute summary statistics and generate MinMaxScalerModel
val scalerModel = scaler.fit(df_tmp)

// rescale each feature to range [min, max].
val scaledData = scalerModel.transform(df_tmp)
println(s"Features scaled to range: [${scaler.getMin}, ${scaler.getMax}]")
scaledData.count()
scaledData.select("features", "MinMaxScalerFeatures").show(5,false)

df_tmp: org.apache.spark.sql.DataFrame = [sepal_length: double, sepal_width: double ... 4 more fields]
scaler: org.apache.spark.ml.feature.MinMaxScaler = minMaxScal_1f3123d5ef9f
scalerModel: org.apache.spark.ml.feature.MinMaxScalerModel = minMaxScal_1f3123d5ef9f
scaledData: org.apache.spark.sql.DataFrame = [sepal_length: double, sepal_width: double ... 5 more fields]
Features scaled to range: [0.0, 1.0]
res29: Long = 150
+-----------------+---------------------------------------------------------------------------------+
|features         |MinMaxScalerFeatures                                                             |
+-----------------+---------------------------------------------------------------------------------+
|[5.1,3.5,1.4,0.2]|[0.22222222222222213,0.6249999999999999,0.06779661016949151,0.04166666666666667] |
|[4.9,3.0,1.4,0.2]|[0.1666666666666668,0.41666666666666663,0.06779661016949151,0.04166666666666667] |
|[4.7,3.2,1.3,0.2]|[0.11111111111111119,0.5,0.05084745762711865,0.04166666666666667]                |
|[4.6,3.1,1.5,0.2]|[0.08333333333333327,0.4583333333333333,0.0847457627118644,0.04166666666666667]  |
|[5.0,3.6,1.4,0.2]|[0.19444444444444448,0.6666666666666666,0.06779661016949151,0.04166666666666667] |
+-----------------+---------------------------------------------------------------------------------+
only showing top 5 rows
```

## StandardScaler
#### Importar librerías
```javascript
import org.apache.spark.ml.feature.MinMaxScaler
import org.apache.spark.ml.linalg.Vectors
```
#### StandardScaler
```javascript
val df_tmp = scaledData

val scaler = new StandardScaler().setInputCol("MinMaxScalerFeatures").setOutputCol("StandardScalerFeatures").setWithStd(true).setWithMean(false)

// Compute summary statistics by fitting the StandardScaler.
val scalerModel = scaler.fit(df_tmp)

// Normalize each feature to have unit standard deviation.
val scaledData = scalerModel.transform(df_tmp)
scaledData.count()
scaledData.select("features", "MinMaxScalerFeatures","StandardScalerFeatures").show(5,false)

df_tmp: org.apache.spark.sql.DataFrame = [sepal_length: double, sepal_width: double ... 5 more fields]
scaler: org.apache.spark.ml.feature.StandardScaler = stdScal_91cd543651fc
scalerModel: org.apache.spark.ml.feature.StandardScalerModel = stdScal_91cd543651fc
scaledData: org.apache.spark.sql.DataFrame = [sepal_length: double, sepal_width: double ... 6 more fields]
res47: Long = 150
+-----------------+--------------------------------------------------------------------------------+-------------------------------------------------------------------------------+
|features         |MinMaxScalerFeatures                                                            |StandardScalerFeatures                                                         |
+-----------------+--------------------------------------------------------------------------------+-------------------------------------------------------------------------------+
|[5.1,3.5,1.4,0.2]|[0.22222222222222213,0.6249999999999999,0.06779661016949151,0.04166666666666667]|[0.9661064170727516,3.459454980596082,0.22670333865826722,0.13103399393571005] |
|[4.9,3.0,1.4,0.2]|[0.1666666666666668,0.41666666666666663,0.06779661016949151,0.04166666666666667]|[0.7245798128045645,2.3063033203973884,0.22670333865826722,0.13103399393571005]|
|[4.7,3.2,1.3,0.2]|[0.11111111111111119,0.5,0.05084745762711865,0.04166666666666667]               |[0.4830532085363763,2.7675639844768662,0.17002750399370045,0.13103399393571005]|
|[4.6,3.1,1.5,0.2]|[0.08333333333333327,0.4583333333333333,0.0847457627118644,0.04166666666666667] |[0.3622899064022817,2.5369336524371273,0.2833791733228341,0.13103399393571005] |
|[5.0,3.6,1.4,0.2]|[0.19444444444444448,0.6666666666666666,0.06779661016949151,0.04166666666666667]|[0.8453431149386581,3.6900853126358215,0.22670333865826722,0.13103399393571005]|
+-----------------+--------------------------------------------------------------------------------+-------------------------------------------------------------------------------+
only showing top 5 rows
```
Visulizar dataframe final
```javascript
scaledData.show
+------------+-----------+------------+-----------+-----------+-----------------+--------------------+----------------------+
|sepal_length|sepal_width|petal_length|petal_width|      label|         features|MinMaxScalerFeatures|StandardScalerFeatures|
+------------+-----------+------------+-----------+-----------+-----------------+--------------------+----------------------+
|         5.1|        3.5|         1.4|        0.2|Iris-setosa|[5.1,3.5,1.4,0.2]|[0.22222222222222...|  [0.96610641707275...|
|         4.9|        3.0|         1.4|        0.2|Iris-setosa|[4.9,3.0,1.4,0.2]|[0.16666666666666...|  [0.72457981280456...|
|         4.7|        3.2|         1.3|        0.2|Iris-setosa|[4.7,3.2,1.3,0.2]|[0.11111111111111...|  [0.48305320853637...|
|         4.6|        3.1|         1.5|        0.2|Iris-setosa|[4.6,3.1,1.5,0.2]|[0.08333333333333...|  [0.36228990640228...|
|         5.0|        3.6|         1.4|        0.2|Iris-setosa|[5.0,3.6,1.4,0.2]|[0.19444444444444...|  [0.84534311493865...|
+------------+-----------+------------+-----------+-----------+-----------------+--------------------+----------------------+
only showing top 5 rows
```



# K-means
Importar librerías
```javascript
import org.apache.spark.ml.clustering.KMeans
import org.apache.spark.ml.evaluation.ClusteringEvaluator
```
StandardScaler
```javascript
val data = scaledData.select("StandardScalerFeatures","label").withColumnRenamed("StandardScalerFeatures","features")
data.printSchema()
data.count()
data.show(2,false)
```

K = 3
```javascript
// Trains a k-means model.
val kmeans = new KMeans().setK(3).setSeed(103L)
val model = kmeans.fit(data)

// Make predictions
val predictions = model.transform(data)

// Evaluate clustering by computing Silhouette score
val evaluator = new ClusteringEvaluator()

println("######################################################################")
val silhouette = evaluator.evaluate(predictions)
println(s"Silhouette with squared euclidean distance = $silhouette")
println("######################################################################")
// Shows the result.
println("Cluster Centers: ")
model.clusterCenters.foreach(println)
println("######################################################################")
predictions.groupBy("prediction").count().show
println("######################################################################")
predictions.show(5)
```

