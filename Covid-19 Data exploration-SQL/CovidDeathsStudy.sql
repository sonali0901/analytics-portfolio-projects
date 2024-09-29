create DATABASE CovidDeaths;
select count(*) from CovidDeaths.dbo.CovidDeaths_cleaned;
select count(*) from CovidDeaths.dbo.CovidDeaths_Vaccination;
SELECT * from CovidDeaths..CovidDeaths_cleaned;
SELECT * from CovidDeaths..CovidDeaths_cleaned ORDER BY 3,4;
select * from CovidDeaths..CovidDeaths_Vaccination;

-- Clean data --
ALTER TABLE CovidDeaths..CovidDeaths_cleaned
ALTER COLUMN date DATE;

ALTER TABLE CovidDeaths..CovidDeaths_Vaccination
ALTER COLUMN date DATE;

SELECT * from CovidDeaths..CovidDeaths_Vaccination ORDER BY 3,4;

SELECT location, date, new_cases, total_cases, total_deaths, population
FROM CovidDeaths..CovidDeaths_cleaned
ORDER BY 1,2;

-- Total cases v/s Total deaths

SELECT location, date, total_cases, total_deaths, (CAST(total_deaths AS float)/CAST(total_cases AS FLOAT))*100 AS death_percent
FROM CovidDeaths..CovidDeaths_cleaned
ORDER BY 1,2;


--- total deaths by the end of the data --- 
-- 1.78% chance of dying(likelihood) of dying if infected in your country
SELECT location, date, total_cases, total_deaths, (CAST(total_deaths AS float)/CAST(total_cases AS FLOAT))*100 AS death_percent
FROM CovidDeaths..CovidDeaths_cleaned
WHERE location like '%states%'
ORDER BY 1,2;

-- Looking at total cases vs population
-- When we hit 1% case rate, to when 10% population got infected
SELECT location, date, total_cases, population, (CAST(total_cases AS float)/CAST(population AS FLOAT))*100 AS case_percent
FROM CovidDeaths..CovidDeaths_cleaned
WHERE location like '%states%'
ORDER BY 1,2;

-- Highest infection rate compared to population
SELECT location, population, MAX(total_cases) AS highest_cases, 
MAX((CAST(total_cases AS float)/CAST(population AS FLOAT))*100) AS highest_case_percent
FROM CovidDeaths..CovidDeaths_cleaned
GROUP BY location, population
ORDER BY highest_case_percent desc;


-- Countries with Highest death count per population
SELECT location, population, MAX(total_deaths) AS total_deaths_count
FROM CovidDeaths..CovidDeaths_cleaned
GROUP BY location, population
ORDER BY total_deaths_count desc;

-- Refine the query to only pull contouries and not continents
SELECT location, population, MAX(total_deaths) AS total_deaths_count
FROM CovidDeaths..CovidDeaths_cleaned
WHERE continent is not null
GROUP BY location, population
ORDER BY total_deaths_count desc;

-- Highlight deaths by continents
-- Show continents with highest death counts
SELECT location, MAX(total_deaths) AS total_deaths_count
FROM CovidDeaths..CovidDeaths_cleaned
WHERE continent is null
GROUP BY location
ORDER BY total_deaths_count desc;

-- GLOBAL NUMBERS EXPLORATION

-- Everyday death percent
SELECT date, SUM(new_cases) as total_cases, SUM(new_deaths) as total_deaths, -- total_deaths, (CAST(total_deaths AS float)/CAST(total_cases AS FLOAT))*100 AS death_percent
CAST(SUM(new_deaths) as float)/CAST(SUM(new_cases) as float)*100 as death_percent
FROM CovidDeaths..CovidDeaths_cleaned
where continent is not null
GROUP BY date
ORDER BY 1,2;

-- Deaths overall around the world
SELECT SUM(new_cases) as total_cases, SUM(new_deaths) as total_deaths, -- total_deaths, (CAST(total_deaths AS float)/CAST(total_cases AS FLOAT))*100 AS death_percent
CAST(SUM(new_deaths) as float)/CAST(SUM(new_cases) as float)*100 as death_percent
FROM CovidDeaths..CovidDeaths_cleaned
where continent is not null
ORDER BY 1,2;

--- Now with vaccination data
SELECT * FROM CovidDeaths..CovidDeaths_cleaned deaths
JOIN CovidDeaths..CovidDeaths_Vaccination vaccinations
ON deaths.location = vaccinations.location
and deaths.date = vaccinations.date;

-- Check how many people in the world are vaccianted
-- Partial
SELECT deaths.continent, deaths.location, deaths.date, deaths.population,
vaccinations.new_vaccinations
 FROM CovidDeaths..CovidDeaths_cleaned deaths
JOIN CovidDeaths..CovidDeaths_Vaccination vaccinations
ON deaths.location = vaccinations.location
and deaths.date = vaccinations.date
where deaths.continent is not null
order by 2,3

-- Rolling count
SELECT deaths.continent, deaths.location, deaths.date, deaths.population,
vaccinations.new_vaccinations,
SUM(vaccinations.new_vaccinations) OVER(PARTITION BY deaths.location ORDER BY deaths.date) as rolling_vaccinations
FROM CovidDeaths..CovidDeaths_cleaned deaths
JOIN CovidDeaths..CovidDeaths_Vaccination vaccinations
ON deaths.location = vaccinations.location
and deaths.date = vaccinations.date
where deaths.continent is not null
order by 2,3

-- Now we want to see the % of people vaccinated by the population of the location
-- use of cte, can location the last entry of the partision to know the final percent
with vaccination_rate (
    continent,location,date,population,new_vaccinations, rolling_vaccinations
) as 
(
    SELECT deaths.continent, deaths.location, deaths.date, deaths.population,
vaccinations.new_vaccinations,
SUM(vaccinations.new_vaccinations) OVER(PARTITION BY deaths.location ORDER BY deaths.date) as rolling_vaccinations
FROM CovidDeaths..CovidDeaths_cleaned deaths
JOIN CovidDeaths..CovidDeaths_Vaccination vaccinations
ON deaths.location = vaccinations.location
and deaths.date = vaccinations.date
where deaths.continent is not null
-- order by 2,3
)
SELECT *, CAST(rolling_vaccinations as float)/CAST(population as float)*100 
as vacinate_percent from vaccination_rate;

-- use temp table

DROP table if exists #percent_population_vaccinated
CREATE TABLE #percent_population_vaccinated
(
    continent nvarchar(255),
    location nvarchar(255),
    date DATE,
    population bigint,
    new_vaccinations bigint,
    rolling_vaccinations bigint,
)
INSERT INTO #percent_population_vaccinated
SELECT deaths.continent, deaths.location, deaths.date, deaths.population,
vaccinations.new_vaccinations,
SUM(vaccinations.new_vaccinations) OVER(PARTITION BY deaths.location ORDER BY deaths.date) as rolling_vaccinations
FROM CovidDeaths..CovidDeaths_cleaned deaths
JOIN CovidDeaths..CovidDeaths_Vaccination vaccinations
ON deaths.location = vaccinations.location
and deaths.date = vaccinations.date
where deaths.continent is not null

SELECT *, CAST(rolling_vaccinations as float)/CAST(population as float)*100 
as vaccinate_percent from #percent_population_vaccinated;

-- Create view for later 
CREATE VIEW view_percent_population as
SELECT SUM(new_cases) as total_cases, SUM(new_deaths) as total_deaths, -- total_deaths, (CAST(total_deaths AS float)/CAST(total_cases AS FLOAT))*100 AS death_percent
CAST(SUM(new_deaths) as float)/CAST(SUM(new_cases) as float)*100 as death_percent
FROM CovidDeaths..CovidDeaths_cleaned
where continent is not null
-- ORDER BY 1,2;