# Clustering en Scala
Importar Librerias
```javascript
// crear Schema
import org.apache.spark.sql.types._
// crear ID incremental
import org.apache.spark.sql.functions._
```

Crear Schema
```javascript
var schema = StructType(Array(
    StructField("sepal_length", DoubleType, true),
    StructField("sepal_width", DoubleType, true),
    StructField("petal_length", DoubleType, true),
    StructField("petal_width", DoubleType, true),
    StructField("label", StringType, true)))
```

Importar Datos
```javascript
var dataset = spark.read.format("csv").
option("header", "true").
option("delimiter",";").
schema(schema).
load("/iris_v2.csv").
select("sepal_length","sepal_width","petal_length","petal_width", "label")
```
Conteo de la data importada
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
Tipo de datos
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
Importar Librerias
```javascript
import org.apache.spark.ml.feature.VectorAssembler
import org.apache.spark.ml.linalg.Vectors
```
Seleccionar variables para el vector assembler
```javascript
val assembler = new VectorAssembler().
setInputCols(Array("sepal_length", "sepal_width", "petal_length", "petal_width")).
//setInputCols(Array("sepal_length", "sepal_width")).
setOutputCol("features")

val output = assembler.transform(dataset)
```
validar resultados vector assembler
```javascript
output.show(2)
+------------+-----------+------------+-----------+-----------+-----------------+ 
|sepal_length|sepal_width|petal_length|petal_width|      label|         features| 
+------------+-----------+------------+-----------+-----------+-----------------+ 
|         5.1| 	      3.5|         1.4|        0.2|Iris-setosa|[5.1,3.5,1.4,0.2]| 
|         4.9|        3.0|         1.4|        0.2|Iris-setosa|[4.9,3.0,1.4,0.2]| 
+------------+-----------+------------+-----------+-----------+-----------------+
```

###  Basic Statistics
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

###  Percentiles
```javascript
output.stat.approxQuantile("sepal_length",Array(0.25,0.5,0.75),0.0)
output.stat.approxQuantile("sepal_width",Array(0.25,0.5,0.75),0.0)
output.stat.approxQuantile("petal_length",Array(0.25,0.5,0.75),0.0)
output.stat.approxQuantile("petal_width",Array(0.25,0.5,0.75),0.0)
```
## Correlation
Imoportar Librerias
```javascript
import org.apache.spark.ml.linalg.{Matrix, Vectors}
import org.apache.spark.ml.stat.Correlation
import org.apache.spark.sql.Row
```

Pearson correlation matrix
```javascript
println(s"Pearson correlation matrix")
val Row(coeff1: Matrix) = Correlation.corr(output.select("features"), "features").head
//println(s"Pearson correlation matrix:\n $coeff1")

coeff1: org.apache.spark.ml.linalg.Matrix = 
1.0 -0.10936924995062468 0.8717541573048866 0.8179536333691776 
-0.10936924995062468 1.0 -0.42051609640115817 -0.35654408961379946 
0.8717541573048866 -0.42051609640115817 1.0 0.9627570970509658 
0.8179536333691776 -0.35654408961379946 0.9627570970509658 1.0
```
## MinMaxScaler
Importar librerías
```javascript
import org.apache.spark.ml.feature.MinMaxScaler
import org.apache.spark.ml.linalg.Vectors
```

MinMaxScaler
```javascript
val df_tmp = output

val scaler = new MinMaxScaler().setInputCol("features").setOutputCol("MinMaxScalerFeatures")

// Compute summary statistics and generate MinMaxScalerModel
val scalerModel = scaler.fit(df_tmp)

// rescale each feature to range [min, max].
val scaledData = scalerModel.transform(df_tmp)
println(s"Features scaled to range: [${scaler.getMin}, ${scaler.getMax}]")
scaledData.count()
scaledData.select("features", "MinMaxScalerFeatures").show(false)
```

## StandardScaler
Importar librerías
```javascript
import org.apache.spark.ml.feature.MinMaxScaler
import org.apache.spark.ml.linalg.Vectors
```
StandardScaler
```javascript
//val dataFrame = spark.read.format("libsvm").load("data/mllib/sample_libsvm_data.txt")
val df_tmp = scaledData

val scaler = new StandardScaler().setInputCol("MinMaxScalerFeatures").setOutputCol("StandardScalerFeatures").setWithStd(true).setWithMean(false)

// Compute summary statistics by fitting the StandardScaler.
val scalerModel = scaler.fit(df_tmp)

// Normalize each feature to have unit standard deviation.
val scaledData = scalerModel.transform(df_tmp)
scaledData.count()
scaledData.select("features", "MinMaxScalerFeatures","StandardScalerFeatures").show(false)
```

