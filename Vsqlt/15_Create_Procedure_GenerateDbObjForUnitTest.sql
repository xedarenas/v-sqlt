IF EXISTS(SELECT 1 FROM sys.procedures 
          WHERE object_id = OBJECT_ID(N'VsqltHelper.GenerateDbObjForUnitTest'))
BEGIN
    DROP PROCEDURE [VsqltHelper].[GenerateDbObjForUnitTest]
END
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [VsqltHelper].[GenerateDbObjForUnitTest]
(
@ATargetDBName NVARCHAR(200),
@AReturnedCount int
)
AS

BEGIN

SET NOCOUNT ON

    DECLARE @returnedCount INT = 0

	IF @AReturnedCount < 1
		SET @returnedCount = 1
	ELSE
	    SET @returnedCount = @AReturnedCount

	DECLARE @SQL NVARCHAR(MAX) = '

	DECLARE @tblObjectToTest TABLE
	(
	[ObjectToTest] [nvarchar](500) NULL,
	[LastAltered] datetime2 NULL
	) 

	INSERT @tblObjectToTest (ObjectToTest,LastAltered) SELECT ''['' + SPECIFIC_SCHEMA + ''].['' + SPECIFIC_NAME + '']'',LAST_ALTERED FROM ' + @ATargetDBName + '.information_schema.routines 
	
	SELECT TOP ' + CONVERT(NVARCHAR(10),@returnedCount) + ' * FROM @tblObjectToTest OT
	WHERE NOT EXISTS 
	(
	SELECT 1 FROM OzTSQLT.ExecutionLog OE
	WHERE OE.ObjectToTest = OT.ObjectToTest
	)
	ORDER BY OT.LastAltered DESC	
	'
	--Execute the generated sql above
	EXEC(@SQL)

SET NOCOUNT OFF

END
