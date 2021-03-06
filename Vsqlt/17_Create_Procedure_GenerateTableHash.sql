IF EXISTS(SELECT 1 FROM sys.procedures 
          WHERE object_id = OBJECT_ID(N'VsqltHelper.GenerateTableHash'))
BEGIN
    DROP PROCEDURE [VsqltHelper].[GenerateTableHash]
END
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [VsqltHelper].[GenerateTableHash]
(
@tableHash NVARCHAR(MAX) OUTPUT
)
AS
BEGIN

SET NOCOUNT ON

DECLARE @SQL varchar(max) = '',
        @tmpsql varchar(100)

--Basically, we are only getting the fieldname and datatype id to be used for generating hash
SELECT name, system_type_id into #tmp1 From tempdb.sys.columns WHERE object_id=OBJECT_ID('tempdb.dbo.#TESTRESULT');

WHILE (select count(1) from #tmp1) > 0
BEGIN
    SET ROWCOUNT 1
    SELECT @tmpsql = name + ' ' + CONVERT(varchar(40),system_type_id) from #tmp1
	SET @SQL = @SQL + ' ' + @tmpsql
	DELETE from #tmp1
	SET ROWCOUNT 0
END

SET @tableHash = master.dbo.fn_varbintohexsubstring(0, HASHBYTES('MD5', @SQL), 1, 0)  

SET NOCOUNT OFF

END
