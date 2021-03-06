IF EXISTS (SELECT 1
           FROM   sys.objects
           WHERE  object_id = OBJECT_ID(N'[VsqltHelper].[BuildSpOrFuncUnderTestName]')
                  AND type IN ( N'FN', N'IF', N'TF', N'FS', N'FT' ))
  DROP FUNCTION [VsqltHelper].[BuildSpOrFuncUnderTestName]

GO 

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [VsqltHelper].[BuildSpOrFuncUnderTestName] (@ATestTargetServerName NVARCHAR(100),@ATestTargetDatabaseName NVARCHAR(100), @ATestTargetSPOrFunc NVARCHAR(100))  
RETURNS NVARCHAR(MAX) 
AS   
-- Returns a string that will basically contruct the callable stored procedure or function to test.
BEGIN  

	DECLARE @retValue NVARCHAR(MAX)
	
	SET @retValue = @ATestTargetDatabaseName + '.' + @ATestTargetSPOrFunc
	IF(@ATestTargetServerName IS NOT NULL)
		SET @retValue = @ATestTargetServerName + '.' + @ATestTargetDatabaseName + '.' + @ATestTargetSPOrFunc

	RETURN @retValue

END
