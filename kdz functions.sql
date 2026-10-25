
			--РАСЧЕТ СТАЖА РАБОТЫ(1) - (VIEW vw_EmployeesOnVacation)
CREATE FUNCTION fn_CalculateWorkExperience (@EmployeeID INT)
RETURNS NVARCHAR(100)
AS
BEGIN
    DECLARE @Result NVARCHAR(100)
    DECLARE @HireDate DATE
    DECLARE @Years INT, @Months INT
    
    SELECT @HireDate = HireDate 
    FROM Employees 
    WHERE EmployeeID = @EmployeeID
    
    IF @HireDate IS NULL
        RETURN 'Не найден сотрудник'
    
    SET @Years = DATEDIFF(YEAR, @HireDate, GETDATE());
    SET @Months = DATEDIFF(MONTH, DATEADD(YEAR, @Years, @HireDate), GETDATE())
    
    IF @Months < 0
    BEGIN
        SET @Years = @Years - 1
        SET @Months = 12 + @Months
    END
    
    SET @Result = CAST(@Years AS NVARCHAR) + ' г. ' + CAST(@Months AS NVARCHAR) + ' мес.';
    RETURN @Result
END



-- Стаж сотрудников
SELECT 
    EmployeeID,
	FirstName + ' ' + LastName as FullName,
    HireDate,
    dbo.fn_CalculateWorkExperience(EmployeeID) as WorkExperience
FROM Employees

-- Стаж сущетсвующего/несуществующего сотрудника
SELECT dbo.fn_CalculateWorkExperience(50) as Experience



			--РАСЧЕТ СРЕДНЕГО ЧЕКА ПО ОТДЕЛУ ЗА ПРОШЛЫЙ МЕСЯЦ(2) - (VIEW vw_DailySalesSummary)
CREATE FUNCTION fn_GetAverageCheckByDepartment (@DepartmentID INT)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @AvgCheck DECIMAL(10,2);
    
    -- Берем прошлый КАЛЕНДАРНЫЙ месяц
    DECLARE @StartDate DATE = DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 1, 0);
    DECLARE @EndDate DATE = DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0);
    
    -- суммы по чекам
    WITH CheckTotals AS (
        SELECT 
            s.SaleID,
            CAST(SUM(si.Quantity * si.UnitPrice) AS DECIMAL(10,2)) as Total
        FROM Sales s
        INNER JOIN SaleItems si ON s.SaleID = si.SaleID
        INNER JOIN Products p ON si.ProductID = p.ProductID
        WHERE p.DepartmentID = @DepartmentID
          AND s.SaleDateTime >= @StartDate 
          AND s.SaleDateTime < @EndDate
        GROUP BY s.SaleID
    )
    
    -- усреднение суммы чеков
    SELECT @AvgCheck = CAST(AVG(Total) AS DECIMAL(10,2))
    FROM CheckTotals
    
    RETURN ISNULL(@AvgCheck, 0)
END



--Средний чек для отдела с продажами в прошлом месяце
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



			--ПРОВЕРКА ДОСТУПНОСТИ СОТРУДНИКА(3) - (TRIGGER trg_PreventEmployeeDelete_Simple)
CREATE FUNCTION fn_IsEmployeeOnVacation (@EmployeeID INT, @CheckDate DATE = NULL)
RETURNS NVARCHAR(100)
AS
BEGIN
	
	IF NOT EXISTS (SELECT 1 FROM Employees WHERE EmployeeID = @EmployeeID)
        RETURN 'Сотрудник не найден'

    IF @CheckDate IS NULL
        SET @CheckDate = CAST(GETDATE() AS DATE)
    
    DECLARE @Result NVARCHAR(100);
    
    IF EXISTS (
        SELECT 1 
        FROM Vacations 
        WHERE EmployeeID = @EmployeeID 
          AND @CheckDate BETWEEN StartDate AND EndDate
    )
    BEGIN
        SET @Result = 'Сотрудник в отпуске'
    END
	ELSE
	BEGIN
        SET @Result = 'Сотрудник доступен'
    END
    
    RETURN @Result
END



--Статус сотрудника (отпуск)
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