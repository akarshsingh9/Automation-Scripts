import pyodbc
import re 

connection = pyodbc.connect('Driver={SQL Server};'
                      'Server=LW-AKARSH;'
                      'Database=LW_MigrationHelper;'
                      'Trusted_Connection=yes;')

cursor = connection.cursor()
cursor.execute('SELECT TOP 1 * FROM ProcessingLogDetail ORDER BY 1 DESC')

staging = ''
for row in cursor:
	errormsg = row[1]
	res = re.findall(r'\bstg\w+',errormsg)
	staging = res[0]

table = staging[3:]

query = ''
if table != 'ProcessingLog' or table != 'ProcessingLogDetail':
	query = "IF NOT EXISTS(select * from sys.synonyms where name = '{0}') \nBEGIN \n CREATE SYNONYM {1} FOR [LW_Intermediate].[dbo].[{2}] \nEND \n\n".format(staging,staging,table)
else:
	query = "IF NOT EXISTS(select * from sys.synonyms where name = '{0}') \nBEGIN \n CREATE SYNONYM {1} FOR [LW_MigrationHelper].[dbo].[{2}] \nEND \n\n".format(staging,staging,table)

file = open(r'C:\Users\Akarsh.Singh\Desktop\python_sql\syn.sql','a')
file.write(query)
file.close()
