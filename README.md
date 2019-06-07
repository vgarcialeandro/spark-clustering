# Clustering en Scala
Imoportar Librerias
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
Imoportar Librerias
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
