			--ФУНКЦИИ
-- Стаж сотрудников(1)
SELECT 
    EmployeeID,
	FirstName + ' ' + LastName as FullName,
    HireDate,
    dbo.fn_CalculateWorkExperience(EmployeeID) as WorkExperience
FROM Employees

-- Стаж сущетсвующего/несуществующего сотрудника
SELECT dbo.fn_CalculateWorkExperience(50) as Experience

--Средний чек для отдела с продажами в прошлом месяце(2)
SELECT 
    d.DepartmentID,
    d.DepartmentName,
    dbo.fn_GetAverageCheckByDepartment(d.DepartmentID) as AverageCheck
FROM Departments d
WHERE d.DepartmentID = 1

SELECT dbo.fn_GetAverageCheckByDepartment(99999) as AverageCheck

--Ежемесячный отчет по отделам
SELECT 
    d.DepartmentName,
    dbo.fn_GetAverageCheckByDepartment(d.DepartmentID) as AvgCheck,
    (SELECT COUNT(*) FROM Sales s 
     INNER JOIN SaleItems si ON s.SaleID = si.SaleID
     INNER JOIN Products p ON si.ProductID = p.ProductID
     WHERE p.DepartmentID = d.DepartmentID
       AND s.SaleDateTime >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 1, 0)
       AND s.SaleDateTime < DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)
    ) as CheckCount
FROM Departments d
ORDER BY AvgCheck DESC

--Статус сотрудника (отпуск)(3)
SELECT 
    e.EmployeeID,
    e.FirstName + ' ' + e.LastName as FullName,
    dbo.fn_IsEmployeeOnVacation(e.EmployeeID, '2025-12-20') as VacationStatus,
    v.StartDate,
    v.EndDate
FROM Employees e
LEFT JOIN Vacations v 
ON e.EmployeeID = v.EmployeeID 
WHERE e.EmployeeID = 6 AND '2025-12-20' BETWEEN v.StartDate AND v.EndDate

--Несушествующий сотрудник
SELECT dbo.fn_IsEmployeeOnVacation(999, NULL) as VacationStatus



			--ПРЕДСТАВЛЕНИЯ
--Все товары(1)
SELECT* FROM vw_ExpiringProducts 
ORDER BY DaysUntilExpiry ASC

--Просроченные товары
SELECT * 
FROM vw_ExpiringProducts 
WHERE ExpiryStatus = 'Просрочен'

--Сотрудники в отпуске(2)
SELECT 
    FullName,
    Position,
    DepartmentName,
    WorkExperience,
    'Отпуск до ' + CONVERT(VARCHAR, EndDate, 104) as 'Return'
FROM vw_EmployeesOnVacation 
WHERE VacationStatus = 'В отпуске'

--Отпуск в январе
SELECT 
    FullName,
    DepartmentName,
	VacationStatus,
    StartDate,
    EndDate
FROM vw_EmployeesOnVacation 
WHERE VacationStatus = 'Отпуск запланирован'
  AND MONTH(StartDate) = 1 
  AND YEAR(StartDate) = 2026
ORDER BY StartDate


--Все аднные за последние 30 дней(3)
SELECT * FROM vw_DailySalesSummary 
ORDER BY SaleDate DESC, TotalRevenue DESC

-- Самые эффективные отделы (макс. средний чек)
SELECT 
    DepartmentName,
    CAST(AVG(AvgCheck) AS DECIMAL(10,2)) as 'AvgCheck for 30 days',
    CAST(MAX(AvgCheck) AS DECIMAL(10,2)) as 'MaxCheck',
    CAST(MIN(AvgCheck) AS DECIMAL(10,2)) as 'MinCheck',
    CAST(AVG(AvgCheckLastMonth) AS DECIMAL(10,2)) as 'AvgCheck for the last mounth',
    CAST(AVG(AvgCheck) - AVG(AvgCheckLastMonth) AS DECIMAL(10,2)) as 'Difference'
FROM vw_DailySalesSummary
GROUP BY DepartmentName
ORDER BY 'AvgCheck for 30 days' DESC

 --Продажи с нулевой выручкой
SELECT * FROM vw_DailySalesSummary 
WHERE TotalRevenue <= 0 OR SalesCount <= 0




			--ПРОЦЕДУРЫ
--Использование(1)
EXEC sp_AddEmployee 
    @FirstName = 'Анна',
    @LastName = 'Смирнова',
    @MiddleName = 'Владимировна',
    @BirthDate = '1997-08-15',
    @Position = 'Кассир',
    @DepartmentID = 8

SELECT* FROM Employees

-- Использование:(2)
EXEC sp_FindProductByName @ProductName = 'батон'

-- Использование:(3)
EXEC sp_ShowLowStockTop5



			--ТРИГГЕРЫ
--Попытка удаления руководства(1)
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

--Попытка удаления просроченных товаров (2)
SELECT* FROM vw_ExpiringProducts
ORDER BY DaysUntilExpiry

DELETE FROM vw_ExpiringProducts

SELECT* FROM vw_ExpiringProducts
ORDER BY DaysUntilExpiry

-- Попытка добавить несовершеннолетнего(3)
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

