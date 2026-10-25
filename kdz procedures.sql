
			--ДОБАВЛЕНИЕ НОВОГО СОТРДУНИКА(1)
CREATE PROCEDURE sp_AddEmployee
    @FirstName NVARCHAR(255),
    @LastName NVARCHAR(255),
    @MiddleName NVARCHAR(255) = NULL,
    @BirthDate DATE,
    @Position NVARCHAR(255),
    @DepartmentID INT = NULL
AS
BEGIN
    SET NOCOUNT ON
 
    INSERT INTO Employees (FirstName, LastName, MiddleName, BirthDate, HireDate, Position, DepartmentID)
    VALUES (@FirstName, @LastName, @MiddleName, @BirthDate, GETDATE(), @Position, @DepartmentID)
    
    PRINT 'Сотрудник успешно добавлен. ID: ' + CAST(SCOPE_IDENTITY() AS NVARCHAR)
END
GO



--Использование
EXEC sp_AddEmployee 
    @FirstName = 'Анна',
    @LastName = 'Смирнова',
    @MiddleName = 'Владимировна',
    @BirthDate = '1997-08-15',
    @Position = 'Кассир',
    @DepartmentID = 8

SELECT* FROM Employees



			--ПОИСК ТОВАРА ПО НАЗВАНИЮ(2)
CREATE PROCEDURE sp_FindProductByName
    @ProductName NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON
    
    SELECT 
        p.ProductID,
        p.ProductName,
        p.Unit,
        d.DepartmentName,
        s.Quantity,
        s.ExpiryDate,
        CASE 
            WHEN DATEDIFF(DAY, GETDATE(), s.ExpiryDate) <= 3 THEN 'Скоро истечет'
            WHEN s.Quantity = 0 THEN 'Нет в наличии'
            ELSE 'В наличии'
        END AS Status
    FROM Products p
    LEFT JOIN Departments d ON p.DepartmentID = d.DepartmentID
    LEFT JOIN Stock s ON p.ProductID = s.ProductID
    WHERE p.ProductName LIKE '%' + @ProductName + '%'
    ORDER BY s.Quantity DESC
END
GO


-- Использование:
EXEC sp_FindProductByName @ProductName = 'батон'



			--ПОСЛЕДНИЕ 5 ТОВАРОВ ПО ОСТАТКАМ(3)
CREATE PROCEDURE sp_ShowLowStockTop5
AS
BEGIN
    SELECT TOP 5
        p.ProductName,
        s.Quantity AS 'Remains',
        p.MinStockLevel AS 'Minimum',
        s.Quantity - p.MinStockLevel AS 'Difference',
        d.DepartmentName 
    FROM Products p
    JOIN Stock s ON p.ProductID = s.ProductID
    JOIN Departments d ON p.DepartmentID = d.DepartmentID
    WHERE s.Quantity <= p.MinStockLevel * 1.5  -- Меньше чем на 50% от минимального
    ORDER BY s.Quantity ASC;  -- Сначала те, у которых меньше всего
END
GO

-- Использование:
EXEC sp_ShowLowStockTop5