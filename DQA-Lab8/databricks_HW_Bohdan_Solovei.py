# Databricks notebook source
# MAGIC %md
# MAGIC ## Databricks Homework
# MAGIC Since in July 2025 Databricks Community Edition was deprecated and instead of creating separate cluster they are being provided in serverless mode it will be easier for you to work with data - since all the data and tables will be saving not only when cluster as active.
# MAGIC
# MAGIC So, no separate activities for cluser creating should be executed - it will be autoattached/started when you will execute any of the cells below.
# MAGIC
# MAGIC
# MAGIC Please, create table in the default schema using file Sales_December_2019.csv. On the left found Catalog => Add Data => Drop files to upload, or click to browse => Sales_December_2019.csv After file will be uploaded, just need to confirm that table should be uploaded.
# MAGIC
# MAGIC  Make sure that the first row is header selected => Create Table. Table will be created with name that you specified (sales_december_2019 by default) You will be able to change the table name later if needed.

# COMMAND ----------

# MAGIC %md
# MAGIC PySpark can process SQL queries as a text. In other words you don't need to switch cell language to SQL.
# MAGIC 1. Write data from table that you created into the dataframe using PySpark with SQL query. Show data in the dataframe

# COMMAND ----------

# Create DataFrame from SQL query
df = spark.sql("""
    SELECT *
    FROM sales_december_2019_csv
""")

display(df)

df.printSchema()


# COMMAND ----------

# MAGIC %md
# MAGIC Any notebook can be parameterized using dbutils.widgets. Try to add one parameter "Product_name" and select data from dataframe filtered by value from this parameter. 
# MAGIC
# MAGIC 2. Select data where product = "product_name" from dataframe using PySpark

# COMMAND ----------

from pyspark.sql.functions import col

dbutils.widgets.text("Product_name", "USB-C Charging Cable")

product_name = dbutils.widgets.get("Product_name")

filtered_df = df.filter(col("Product") == product_name)

display(filtered_df)

# COMMAND ----------

# MAGIC %md
# MAGIC As well as in SQL, in PySpark you can use aggregate functions. Package pyspark.sql.functions contains all aggregated function from SQL. Try to perform simple aggregation with dataframe. Don't forget, that column types, which you want to calculate, shoud be numerical.  
# MAGIC 3. Calculate the sales for each product, including the number of products sold

# COMMAND ----------

from pyspark.sql.functions import col, sum as spark_sum

# Remove duplicated header / invalid rows
clean_df = (
    df
    .filter(col("Quantity Ordered") != "Quantity Ordered")
    .filter(col("Price Each") != "Price Each")
)

# Convert columns to numeric types
sales_df = (
    clean_df
    .withColumn("Quantity Ordered", col("Quantity Ordered").cast("int"))
    .withColumn("Price Each", col("Price Each").cast("double"))
)

# Calculate sales amount for each row
sales_df = sales_df.withColumn(
    "Sales",
    col("Quantity Ordered") * col("Price Each")
)

# Aggregate sales by product
product_sales_df = (
    sales_df
    .groupBy("Product")
    .agg(
        spark_sum("Quantity Ordered").alias("Products_Sold"),
        spark_sum("Sales").alias("Total_Sales")
    )
    .orderBy(col("Total_Sales").desc())
)

display(product_sales_df)

# COMMAND ----------

# MAGIC %md
# MAGIC In the PySpark you can perform dataframe profiling using one of two special commands or simple aggregated functions. Try to find special commands to complete this task or just use aggregated functions. Hint: please, сhange the column data types based on the data in them
# MAGIC
# MAGIC 4. Show data profiles output for the new dataframe of table sales_december_2019_csv: row count, min and max value for each column

# COMMAND ----------

from pyspark.sql.functions import expr, to_timestamp, col

# Create dataframe with safe type conversion
profile_df = (
    df
    .withColumn(
        "Order ID",
        expr("try_cast(`Order ID` as int)")
    )
    .withColumn(
        "Quantity Ordered",
        expr("try_cast(`Quantity Ordered` as int)")
    )
    .withColumn(
        "Price Each",
        expr("try_cast(`Price Each` as double)")
    )
    .withColumn(
        "Order Date",
        to_timestamp(col("Order Date"), "MM/dd/yy HH:mm")
    )
)

profile_df = profile_df.filter(
    col("Order ID").isNotNull() &
    col("Quantity Ordered").isNotNull() &
    col("Price Each").isNotNull()
)

# Show row count
print("Row count:", profile_df.count())

# Show count, min and max for columns
display(
    profile_df.summary(
        "count",
        "min",
        "max"
    )
)

# COMMAND ----------

# MAGIC %md
# MAGIC
# MAGIC 5. Add new column to the dataframe from previous task with any default value that you want

# COMMAND ----------

from pyspark.sql.functions import lit

# Add a new column with a default value
df_with_new_column = profile_df.withColumn(
    "Source",
    lit("December_2019")
)

display(df_with_new_column)

# COMMAND ----------

# MAGIC %md
# MAGIC Temporary views are processed by cluster and always dropped when the session ends (when the cluster turns off).
# MAGIC
# MAGIC 6. Create temporary view from task 4 dataframe using PySpark and perform any select using SQL

# COMMAND ----------

profile_df.createOrReplaceTempView("sales_december_view")


# COMMAND ----------

# MAGIC %sql
# MAGIC
# MAGIC SELECT
# MAGIC     Product,
# MAGIC     SUM(`Quantity Ordered`) AS total_quantity,
# MAGIC     ROUND(SUM(`Quantity Ordered` * `Price Each`), 2) AS total_sales
# MAGIC FROM sales_december_view
# MAGIC GROUP BY Product
# MAGIC ORDER BY total_sales DESC;