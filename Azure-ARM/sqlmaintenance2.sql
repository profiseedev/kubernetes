	DECLARE @SchemaNamePK VARCHAR(255)
	DECLARE @TableNamePK VARCHAR(255)
	DECLARE @IndexNamePK VARCHAR(255)
	DECLARE @sqlPK NVARCHAR(500)
	DECLARE @fillfactorPK INT = 80;
	DECLARE TableCursorPK CURSOR FOR
	select s.name, t.name, i.name from sys.tables t inner join sys.schemas s on t.schema_id = s.schema_id inner join sys.indexes i on i.object_id = t.object_id ORDER BY t.name
	OPEN TableCursorPK
	FETCH NEXT FROM TableCursorPK INTO @SchemaNamePK,@TableNamePK,@IndexNamePK
	
	WHILE @@FETCH_STATUS = 0
	        BEGIN
	--Ignore the following table due to index on icon column that cannot be altered Online
	    If @TableNamePK <>  'tGlobalPortalApplicationConfiguration' and @TableNamePK <> 'tPortalApplicationIcon'
	        SET @sqlPK = 'ALTER INDEX [' + @IndexNamePK + '] ON [' + @SchemaNamePK + '].[' + @TableNamePK + ']  REBUILD WITH (FILLFACTOR = ' + CONVERT(VARCHAR(3),@fillfactorPK) + ', Online = ON )'
	        PRINT @sqlPK
	        EXEC (@sqlPK)
	        FETCH NEXT FROM TableCursorPK INTO @SchemaNamePK,@TableNamePK,@IndexNamePK
	     
	END
	CLOSE TableCursorPK
DEALLOCATE TableCursorPK
exec sp_updatestats