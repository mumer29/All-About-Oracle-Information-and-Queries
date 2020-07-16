$env:ORACLE_HOME='c:\oracle\18c'

$oraDataAccessDll="$env:ORACLE_HOME\ODP.NET\managed\common\Oracle.ManagedDataAccess.dll"

if (-not (test-path $oraDataAccessDll)) {
   write-output "$oraDataAccessDll not found"
   exit
}

# echo $oraDataAccessDll

add-type -path $oraDataAccessDll
# [System.Reflection.Assembly]::LoadFrom($oraDataAccessDll)

$connStr = 'User Id=rene;password=rene;data source=ORA18' #  + $username + ';Password=' + $password + ';Data Source=' + $datasource

$conn = new-object Oracle.ManagedDataAccess.Client.OracleConnection($connStr)
# $conn.GetType().FullName          # Oracle.ManagedDataAccess.Client.OracleConnection
# $conn.GetType().BaseType.FullName # System.Data.Common.DbConnection

# echo 1
$conn.Open()
# echo 2
$cmd = $conn.CreateCommand()
# echo 3

# $cmd.GetType().FullName          # Oracle.ManagedDataAccess.Client.OracleCommand
# $cmd.GetType().BaseType.FullName          # System.Data.Common.DbCommand
# $cmd.GetType().BaseType.BaseType.FullName          # System.ComponentModel.Component
# echo 4
# $cmd.GetType().BaseType.FullName # System.Data.Common.DbConnection

$cmd.CommandText = 'select table_name, num_rows from user_tables'

$rdr = $cmd.ExecuteReader()
$rdr.GetType().FullName                       # Oracle.ManagedDataAccess.Client.OracleDataReader
$rdr.GetType().BaseType.FullName              # System.Data.Common.DbDataReader
$rdr.GetType().BaseType.BaseType.FullName     # System.MarshalByRefObject

while ($rdr.Read()) {
  '  {0,-30} - {1,9}' -f $rdr.GetString(0), $rdr.GetInt64(1)
}

