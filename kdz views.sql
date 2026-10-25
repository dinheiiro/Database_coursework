
			--ТОВАРЫ С ИСТЕКАЮЩИМ СРОКОМ ГОДНОСТИ(1)		
CREATE VIEW vw_ExpiringProducts 
AS
SELECT 
    p.ProductID,
    p.ProductName,
    d.DepartmentName,
    s.Quantity,
    s.ExpiryDate,
    DATEDIFF(DAY, GETDATE(), s.ExpiryDate) AS DaysUntilExpiry,
    CASE 
        WHEN DATEDIFF(DAY, GETDATE(), s.ExpiryDate) <= 0 THEN 'Просрочен'
        WHEN DATEDIFF(DAY, GETDATE(), s.ExpiryDate) <= 7 THEN 'Срок годности скоро выйдет'
        ELSE 'В норме'
    END AS ExpiryStatus
FROM Stock s
JOIN Products p ON s.ProductID = p.ProductID
JOIN Departments d ON p.DepartmentID = d.DepartmentID
WHERE s.Quantity > 0
 
--Все товары
SELECT* FROM vw_ExpiringProducts 
ORDER BY DaysUntilExpiry ASC

--Просроченные товары
SELECT * 
FROM vw_ExpiringProducts 
WHERE ExpiryStatus = 'Просрочен'





			--СОТРУДНИКИ В ОТПУСКЕ(2)
CREATE VIEW vw_EmployeesOnVacation 
AS
SELECT 
    e.EmployeeID,
    e.LastName + ' ' + e.FirstName + ' ' + COALESCE(e.MiddleName, '') AS FullName,
    e.Position,
    d.DepartmentName,
    dbo.fn_CalculateWorkExperience(e.EmployeeID) AS WorkExperience,			--ФУНКЦИЯ - РАСЧЕТ СТАЖА РАБОТЫ(1)
    v.StartDate,
    v.EndDate,
    DATEDIFF(DAY, v.StartDate, v.EndDate) + 1 AS VacationDays,
    CASE 
        WHEN GETDATE() BETWEEN v.StartDate AND v.EndDate THEN 'В отпуске'
        WHEN v.StartDate > GETDATE() THEN 'Отпуск запланирован'
        ELSE 'Отпуск закончился'
    END AS VacationStatus
FROM Employees e
JOIN Vacations v ON e.EmployeeID = v.EmployeeID
LEFT JOIN Departments d ON e.DepartmentID = d.DepartmentID
WHERE v.StartDate <= DATEADD(MONTH, 3, GETDATE()) AND v.EndDate >= DATEADD(MONTH, -1, GETDATE())
		
--Сотрудники в отпуске
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




			--ЕЖЕДНЕВНАЯ ФИНАНСОВАЯ СВОДКА ((3)  Продажи по дням и отделам, показывает выручку, количество чеков, средний чек, сравнивает с прошлым месяцем
CREATE VIEW vw_DailySalesSummary
AS
SELECT 
    CAST(s.SaleDateTime AS DATE) AS SaleDate,
    d.DepartmentName,
    COUNT(DISTINCT s.SaleID) AS SalesCount,
    CAST(SUM(si.Quantity * si.UnitPrice) AS DECIMAL(10,2)) AS TotalRevenue,   
    CAST(SUM(si.Quantity) AS DECIMAL(10,1)) AS TotalItemsSold,               
    CAST(SUM(si.Quantity * si.UnitPrice) / COUNT(DISTINCT s.SaleID) AS DECIMAL(10,2)) AS AvgCheck,
    CAST(dbo.fn_GetAverageCheckByDepartment(d.DepartmentID) AS DECIMAL(10,2)) AS AvgCheckLastMonth			--ФУНКЦИЯ - --РАСЧЕТ СРЕДНЕГО ЧЕКА ПО ОТДЕЛУ ЗА ПРОШЛЫЙ МЕСЯЦ(2)
FROM Sales s
JOIN SaleItems si ON s.SaleID = si.SaleID
JOIN Products p ON si.ProductID = p.ProductID
JOIN Departments d ON p.DepartmentID = d.DepartmentID
WHERE s.SaleDateTime >= DATEADD(DAY, -30, GETDATE()) -- последние 30 дней
GROUP BY CAST(s.SaleDateTime AS DATE), d.DepartmentName, d.DepartmentID;

--Все аднные за последние 30 дней
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