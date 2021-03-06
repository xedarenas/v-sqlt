IF EXISTS(SELECT 1 FROM sys.procedures 
          WHERE object_id = OBJECT_ID(N'VsqltHelper.DetermineObjectType'))
BEGIN
    DROP PROCEDURE [VsqltHelper].[DetermineObjectType]
END
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [VsqltHelper].[DetermineObjectTye]
(
@ATargetDatabaseName NVARCHAR(100), 
@ASPFunctionName NVARCHAR(100),
@ObjectType NVARCHAR(30) OUTPUT
)  
AS   
BEGIN  
	
	CREATE TABLE #TmpObjectType
	(
		ObjectType NVARCHAR(30)
	)
	DECLARE @SQL NVARCHAR(MAX) = 'INSERT #TmpObjectType (ObjectType) SELECT TYPE FROM ' +  @ATargetDatabaseName + '.sys.objects where object_id = object_id(''' + @ASPFunctionName + ''')'
	EXEC(@SQL)

	DECLARE @tmpObjectType NVARCHAR(30) = (SELECT ObjectType FROM #TmpObjectType)

	IF(@tmpObjectType IS NOT NULL)
		BEGIN
			SELECT @ObjectType =   
				CASE   
					WHEN UPPER(LTRIM(RTRIM(@tmpObjectType))) IN ('FN','IF') THEN 'FUNCTION'   
					WHEN UPPER(LTRIM(RTRIM(@tmpObjectType))) = ('P') THEN 'STORED_PROCEDURE'   
					ELSE 'OTHER_OBJECTS'  END
		END
	ELSE
		SET @ObjectType = 'NOT_EXIST'

END
