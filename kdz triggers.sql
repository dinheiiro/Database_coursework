	
			--ЗАЩИТА УДАЛЕНИЯ СОТРУДНИКОВ(1) 		
CREATE TRIGGER trg_PreventEmployeeDelete_Simple
ON Employees
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON
    DECLARE @EmployeeID INT
    DECLARE @Position NVARCHAR(255)
    DECLARE @VacationStatus NVARCHAR(100)
    
    SELECT 
        @EmployeeID = EmployeeID,
        @Position = Position
    FROM deleted --  таблица с удаляемыми строками
    SET @VacationStatus = dbo.fn_IsEmployeeOnVacation(@EmployeeID, GETDATE())			--ФУНКЦИЯ - ПРОВЕРКА ДОСТУПНОСТИ СОТРУДНИКА(3)
    
    -- 1 нельзя удалить руководство
    IF @Position IN ('Директор', 'Заместитель директора')
    BEGIN
        RAISERROR('Удаление руководства запрещено', 16, 1)
        RETURN
    END
    
    -- 2 проверка отпуска
    IF @VacationStatus = 'Сотрудник в отпуске'
    BEGIN
        RAISERROR('Нельзя удалить сотрудника в отпуске', 16, 1)
        RETURN
    END
    
    -- 3 для продавцов проверка продаж
    IF @Position IN ('Продавец', 'Кассир', 'Продавец-консультант', 'Консультант')
    BEGIN
        IF EXISTS (SELECT 1 FROM Sales 
                   WHERE EmployeeID = @EmployeeID 
                   AND SaleDateTime > DATEADD(MONTH, -3, GETDATE()))
        BEGIN
            RAISERROR('Нельзя удалить продавца с продажами за 3 месяца', 16, 1)
            RETURN
        END
    END
    
    BEGIN TRANSACTION
    
    DELETE FROM Vacations WHERE EmployeeID = @EmployeeID
    UPDATE Sales SET EmployeeID = NULL WHERE EmployeeID = @EmployeeID
    DELETE FROM Employees WHERE EmployeeID = @EmployeeID
   
    COMMIT TRANSACTION
    
    PRINT 'Сотрудник удален, статус перед удалением: ' + @VacationStatus
END



--Попытка удаления руководства 
BEGIN TRY
    DELETE FROM Employees WHERE EmployeeID = 1;
    PRINT 'Удалено'
END TRY
BEGIN CATCH
    PRINT 'Ошибка: ' + ERROR_MESSAGE() 
END CATCH

--Попытка удаление сотрудника с продажами
SELECT dbo.fn_IsEmployeeOnVacation(4, '2025-12-20') as Status
DELETE FROM Employees WHERE EmployeeID = 4

--Попытка удаления сотрудник в отпуске 
BEGIN TRY
    DELETE FROM Employees WHERE EmployeeID = 6
    PRINT 'Удалено'
END TRY
BEGIN CATCH
    PRINT 'Ошибка: ' + ERROR_MESSAGE()  
END CATCH



			--УДАЛЕНИЕ ПРОСРОЧЕННЫХ ТОВАРОВ(2)
CREATE TRIGGER trg_DeleteExpiredProducts_Cursor
ON vw_ExpiringProducts										--ПРЕДСТАВЛЕНИЕ - VIEW vw_ExpiringProducts 
INSTEAD OF DELETE
AS
BEGIN
    DECLARE @ProductID INT
    DECLARE @StockID INT
    
    -- Курсор для прохода по удаляемым просроченным товарам
    DECLARE expired_cursor CURSOR FOR
    SELECT 
        s.StockID,
        d.ProductID 
    FROM deleted d
    INNER JOIN Stock s ON d.ProductID = s.ProductID
    WHERE d.ExpiryStatus = 'Просрочен'
    
    OPEN expired_cursor
    FETCH NEXT FROM expired_cursor INTO @StockID, @ProductID
    
    WHILE @@FETCH_STATUS = 0
    BEGIN

        DELETE FROM OrderItems 
        WHERE StockID = @StockID
       
        DELETE FROM Stock 
        WHERE StockID = @StockID
        
        FETCH NEXT FROM expired_cursor INTO @StockID, @ProductID
    END
    
    CLOSE expired_cursor
    DEALLOCATE expired_cursor
END
GO

SELECT* FROM vw_ExpiringProducts
ORDER BY DaysUntilExpiry

DELETE FROM vw_ExpiringProducts

SELECT* FROM vw_ExpiringProducts
ORDER BY DaysUntilExpiry



			--ПРОВЕРКА ВОЗРАСТА ПРИ НАЙМЕ СОТРУДНИКА(3)
CREATE TRIGGER trg_CheckEmployeeAge
ON Employees
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON
   
	-- Проверка некорректных дат
    IF EXISTS (
        SELECT 1 
        FROM inserted i
        WHERE i.BirthDate > i.HireDate          
           OR i.BirthDate > GETDATE()         
           OR i.HireDate > DATEADD(YEAR, 1, GETDATE())  
    )
    BEGIN
        RAISERROR('Ошибка: некорректные даты', 16, 1)
        ROLLBACK TRANSACTION
		RETURN
    END

    -- Проверка возраста сотрудника при найме
    IF EXISTS (
        SELECT 1 
        FROM inserted i
        WHERE DATEDIFF(YEAR, i.BirthDate, i.HireDate) < 18
    )
    BEGIN
        RAISERROR('Ошибка: нельзя нанять сотрудника младше 18 лет', 16, 1)
        ROLLBACK TRANSACTION
		RETURN
    END
	
    DECLARE @Message NVARCHAR(1000) = ''

    -- 1 Старше 65 лет
    IF EXISTS (
        SELECT 1 
        FROM inserted i
        WHERE DATEDIFF(YEAR, i.BirthDate, i.HireDate) > 65
    )
    SET @Message = @Message + 'Сотрудник старше 65 лет' + CHAR(10)

    -- 2 Предпенсионный возраст (60-65 лет) 
    IF EXISTS (
        SELECT 1 
        FROM inserted i
        WHERE DATEDIFF(YEAR, i.BirthDate, i.HireDate) BETWEEN 60 AND 65
    )
    SET @Message = @Message + 'Сотрудник предпенсионного возраста (60-65 лет)' + CHAR(10)

    IF LEN(@Message) > 0
        PRINT 'Внимание:' + CHAR(10) + @Message
END
GO

-- Попытка добавить несовершеннолетнего 
BEGIN TRY
    INSERT INTO Employees (FirstName, LastName, BirthDate, HireDate, Position, DepartmentID)
    VALUES ('Иван', 'Молодой', '2025-01-01', '2025-12-20', 'Стажер', 1)
    
    PRINT 'Сотрудник добавлен'
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE()
END CATCH

--Попытка добавить >65 лет
BEGIN TRY
    INSERT INTO Employees (FirstName, LastName, BirthDate, HireDate, Position, DepartmentID)
    VALUES ('Петр', 'Пожилой', '1955-01-01', '2025-12-20', 'Консультант', 2)
  
	SELECT * FROM Employees WHERE LastName = 'Пожилой'
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE()
END CATCH

