-- ============================================================
-- Домашнее задание к лекции «SQL. Введение»
-- Школа Аналитиков · учебная база hh_school
-- Автор: Коняхин Никита Андреевич
-- ============================================================
-- Формат: задания по порядку, каждое начинается с комментария
-- с номером; под каждым запросом — вывод (2–3 предложения).
-- Запрос без вывода не засчитывается.
-- ============================================================

SET search_path TO hh_school;

-- ============================================================
-- БЛОК А. Разминка: термины и структура (текстом)
-- ============================================================

-- ЗАДАНИЕ А1
-- 1. Категория и конкретный тип колонок:
--    vacancies.salary_from        — категория: числовой      тип: INTEGER
--    vacancies.vacancy_name       — категория: строковый     тип: TEXT
--    vacancies.published_at       — категория: дата и время  тип: TIMESTAMP
--    employers.is_accredited_it   — категория: логический    тип: BOOLEAN
--    responses.created_at         — категория: дата и время  тип: TIMESTAMP
--
-- 2. Первичные ключи таблиц:
--    areas:           area_id
--    employers:       employer_id
--    vacancies:       vacancy_id
--    vacancy_details: vacancy_id 
--    responses:       response_id
--    
--    Особенность vacancy_details: тут одновременно и PK, и FK на vacancies.vacancy_id. 
--    Совмещение в одной колонке задаёт связь 1:1: у вакансии не более одного описания. 

-- 3. Почему vacancy_name не может быть первичным ключом:

--    Первичный ключ должен однозначно указывать на одну строку, а название
--    вакансии не уникально. Одни и те же позиции публикуют разные компании
--    в разных регионах и в разное время. 

--    Запрос для подтверждения:

SELECT vacancy_name,
    COUNT(*) AS cnt
FROM vacancies
GROUP BY vacancy_name
ORDER BY cnt DESC;


-- Вывод:
-- Самое частое название «Стажёр: аналитик данных» встречается в базе 6 раз,
-- значит 6 вакансий невозможно различить по имени, поэтому колонка
-- vacancy_name не уникальна и не может служить первичным ключом.


-- 4. Что произойдёт при записи строки «по договорённости» в salary_from:
--    СУБД отклонит вставку и выдаст ошибку несовместимости типов, потому что
--    salary_from объявлен как INTEGER, а «по договорённости» это текст.

-- ============================================================
-- БЛОК Б. Первые запросы: SELECT, WHERE, ORDER BY
-- ============================================================

-- ЗАДАНИЕ Б1
-- Запрос: experienc
SELECT DISTINCT experience
FROM vacancies
ORDER BY experience;


-- Запрос: employment
SELECT DISTINCT employment
FROM vacancies
ORDER BY employment;

-- Запрос: professional_role
SELECT DISTINCT professional_role
FROM vacancies
ORDER BY professional_role;

-- Вывод:
-- experience содержит 3 градации опыта,
-- employment содержит 3 формы занятости, 
-- professional_role содержит 5 направлений, 
-- пустых значений нет и нет одинаковых значений, записанных по-разному. 
-- поэтому по этим колонкам можно безопасно фильтровать и группировать


-- ЗАДАНИЕ Б2
-- Запрос 1: стажировки в Москве без опыта, вакансия открыта
SELECT
    vacancy_id,
    vacancy_name,
    salary_from,
    published_at
FROM vacancies
WHERE area_id = 1
  AND employment = 'Стажировка'
  AND experience = 'Нет опыта'
  AND closed_at IS NULL
ORDER BY published_at DESC;

-- Запрос 2: топ-10 вакансий по salary_from
SELECT
    vacancy_name,
    professional_role,
    salary_from
FROM vacancies
WHERE salary_from IS NOT NULL
ORDER BY salary_from DESC
LIMIT 10;

-- Вывод:
-- Первый запрос нашёл 8 стажировок в Москве. Если убрать московский фильтр, список расширится до 10. 
-- Это означает, что Москва покрывает большую часть предложений


-- ЗАДАНИЕ Б3
-- Ловушка 1. NULL — выполнить и объяснить результат
SELECT count(*) FROM vacancies WHERE closed_at = NULL;
SELECT count(*) FROM vacancies WHERE closed_at IS NULL;

-- Ловушка 2. AND / OR — выполнить и объяснить результат
SELECT count(*) FROM vacancies
WHERE area_id = 1 OR area_id = 2 AND experience = 'Нет опыта';

SELECT count(*) FROM vacancies
WHERE (area_id = 1 OR area_id = 2) AND experience = 'Нет опыта';

-- Вывод 1:
-- = NULL вернул 0 строк, IS NULL  33. Сравнение с отсутствием значения всегда ничего не даёт , 
-- поэтому фильтр отсекает все открытые вакансии. Это опасно, т к может решить, что открытых вакансий нет. 
-- Содержательно closed_at IS NULL означает, что дата закрытия не установлена, поэтому вакансия активна.

-- Вывод 2:
-- Без скобок был применен приоритет AND над OR поэтому условие такое: 
-- "все вакансии Москвы ИЛИ (вакансии СПб без опыта)". Требование к опыту проигнорировалось 
-- для Москвы, поэтому запрос вернул 31 строку вместо корректных 20. 
-- Второй запрос со скобками отвечает на задачу: "(Москва или СПб) И обязательно без опыта".

-- ============================================================
-- БЛОК В. Агрегации и метрики
-- ============================================================

-- ЗАДАНИЕ В1
-- Запрос 1: счётчики (строки, зарплата указана, направления, работодатели)
SELECT
    count(*) AS all_vacancies,
    count(salary_from) AS with_salary,
    count(DISTINCT professional_role) AS roles_cnt,
    count(DISTINCT employer_id) AS employers_cnt
FROM vacancies;

-- Запрос 2: доля активных вакансий (без JOIN)
SELECT
    count(*) FILTER (WHERE closed_at IS NULL) AS open_cnt,
    count(*) FILTER (WHERE closed_at IS NOT NULL) AS closed_cnt,
    round( 100.0 * count(*) FILTER (WHERE closed_at IS NULL) / nullif(count(*), 0), 1 ) AS open_pct
FROM vacancies;

-- Вывод:
-- Разница:
-- count(*) вернул 52 это общее число вакансий в таблице, включая те, где зарплата не указана.
-- count(salary_from) вернул 44 это только вакансии с заполненной зарплатой. 
-- count(DISTINCT professional_role) вернул 5 это уникальные направления рынка.
-- count(DISTINCT employer_id) вернул 12 это уникальные работодатели, представленные в базе.

-- Ответ руководителю:
-- «Сейчас открыто 33 вакансии из 52 это 63,5% рынка.»


-- ЗАДАНИЕ В2
-- Запрос 1: направления — вакансии, работодатели, средняя зарплата
SELECT
    professional_role,
    count(*) AS vacancies_cnt,
    count(DISTINCT employer_id) AS employers_cnt,
    round(avg(salary_from)) AS avg_salary_from
FROM vacancies
GROUP BY professional_role
ORDER BY vacancies_cnt DESC;


-- Запрос 2: то же, только направления с ≥ 5 открытыми вакансиями (WHERE + HAVING)
SELECT
    professional_role,
    count(*) AS open_vacancies_cnt,
    count(DISTINCT employer_id) AS employers_cnt,
    round(avg(salary_from)) AS avg_salary_from
FROM vacancies
WHERE closed_at IS NULL            
GROUP BY professional_role
HAVING count(*) >= 5              
ORDER BY open_vacancies_cnt DESC;

-- Вывод:
-- 1. Больше половины рынка занимают Аналитик данных(16) и Разработчик(15), что вместе 31 из 52 вакансий (~60%). 
--    Соискатель мог бы решить, что нужно идти туда, где больше всего предложений. 
--    Но этой таблицы недостаточно для обоснованного вывода, т к
--    она не показывает конкуренцию и реальную вероятность приглашения. 

-- 2. Условие «только открытые» пишется в WHERE, потому что оно фильтрует строки исходной таблицы 
--    до объединения их в группы. Условие «не менее пяти» пишется в HAVING, т к оно проверяет 
--    результат агрегатной функции count(*), которая появляется только после GROUP BY. 
--    Если попытаться написать WHERE count(*) >= 5, база выдаст ошибку, потому что при выполнении WHERE агрегаты ещё не посчитаны.

-- 3. Значение avg(salary_from) отвечает на вопрос «Какая средняя нижняя граница зарплаты 
--    среди вакансий этого направления, где зарплата явно указана?». 
--	  Оно не отвечает на вопрос о реальной средней рыночной зарплате или среднем оффере.

-- ============================================================
-- БЛОК Г. Соединение таблиц
-- ============================================================

-- ЗАДАНИЕ Г1
-- Запрос: топ-5 по salary_from с названием компании и городом (псевдонимы таблиц)
SELECT
    v.vacancy_name,
    e.employer_name,
    a.area_name,
    v.salary_from
FROM vacancies v
JOIN employers e ON v.employer_id = e.employer_id
JOIN areas a     ON v.area_id = a.area_id
ORDER BY v.salary_from DESC NULLS LAST
LIMIT 5;

-- Вывод:
-- Если убрать псевдонимы и написать просто area_id, возникнет ошибка (ERROR: column reference "area_id" is ambiguous),
-- колонка area_id есть и в таблице vacancies, и в таблице employers. База не поймёт, какой именно ID брать и запрос упадет. 


-- ЗАДАНИЕ Г2
-- Запрос 1: все работодатели, число вакансий и откликов (LEFT JOIN)
SELECT
    e.employer_name,
    count(DISTINCT v.vacancy_id) AS vacancies_cnt,
    count(r.response_id) AS responses_cnt
FROM employers e
LEFT JOIN vacancies v ON e.employer_id = v.employer_id
LEFT JOIN responses r ON v.vacancy_id = r.vacancy_id
GROUP BY e.employer_id, e.employer_name
ORDER BY responses_cnt DESC, e.employer_name;

-- Запрос 2: тот же запрос с INNER JOIN
SELECT
    e.employer_name,
    count(DISTINCT v.vacancy_id) AS vacancies_cnt,
    count(r.response_id) AS responses_cnt
FROM employers e
INNER JOIN vacancies v ON e.employer_id = v.employer_id
INNER JOIN responses r ON v.vacancy_id = r.vacancy_id
GROUP BY e.employer_id, e.employer_name
ORDER BY responses_cnt DESC, e.employer_name;

-- Вывод:
-- 1. Количество вакансий приходится считать через count(DISTINCT ), а не через count(*), 
--    потому что после соединения с таблицей responses одна вакансия дублируется столько раз, сколько у неё откликов. 
--    Обычный count(*) посчитал бы строки результата, а нужно чистое число уникальных объектов.

-- 2. Во втором запросе исчезла компания «ГринЭнерго». Это содержательная потеря, т к hr-менеджеру важно 
--    видеть партнёров с нулевой активностью, чтобы спросить у них «почему нет интереса?», а не просто игнорировать их из-за отсутствия связей.

-- 3. Правило! 
--    если нужны только связанные данные, то берём INNER JOIN. 
--    если нужно сохранить всю основу отчёта, даже  при отсутствии связей, то берем LEFT JOIN.


-- ============================================================
-- БЛОК Д. Функции и финальный кейс
-- ============================================================

-- ЗАДАНИЕ Д1
-- Запрос: помесячная динамика откликов и конверсия
-- (месяц как дата, условный агрегат, nullif в знаменателе)
SELECT
    date_trunc('month', created_at)::date AS month,
    count(response_id) AS responses_cnt,
    count(response_id) FILTER (WHERE status = 'invited') AS invited_cnt,
    round(100.0 * count(response_id) FILTER (WHERE status = 'invited') / nullif(count(response_id), 0),1) AS conversion_pct
FROM responses
GROUP BY 1
ORDER BY 1;


-- Вывод:
-- Максимальная конверсия была в июне 2026 года = 19,5%. 
-- Этому месяцу можно доверять, так как объём выборки репрезентативен, было получено 118 откликов.
-- Последний месяц неполный, здесь всего 41 отклик и конверсия резко упала до 7,3%, скорее всего это статистическая аномалия.


-- ЗАДАНИЕ Д2
-- Запрос: таблица по направлениям (вакансии, отклики, приглашения,
-- откликов на вакансию, конверсия)
SELECT
    v.professional_role,
    count(DISTINCT v.vacancy_id) AS vacancies_cnt,
    count(r.response_id) AS responses_cnt,
    count(r.response_id) FILTER (WHERE r.status = 'invited') AS invited_cnt,
    round(1.0 * count(r.response_id) / nullif(count(DISTINCT v.vacancy_id), 0), 2) AS avg_responses_per_vacancy,
    round(100.0 * count(r.response_id) FILTER (WHERE r.status = 'invited')/ nullif(count(r.response_id), 0), 1) AS conversion_pct
FROM vacancies v
LEFT JOIN responses r ON v.vacancy_id = r.vacancy_id
GROUP BY v.professional_role
ORDER BY conversion_pct DESC, v.professional_role;




-- Письменные ответы:
-- 1. Совпадает ли направление с наибольшим числом вакансий с направлением
--    с наибольшей конверсией?
--    Нет, не совпадает. Больше всего вакансий у «Аналитика данных» (16), а лучшая конверсия у «Тестировщика» (35,9%).
--
-- 2. Какое направление выбрать и почему (опираясь на два столбца):
--    Очень хочется выбрать Аналитика, но по цифрам лучше выбрать Тестировщика. Это направление оптимизирует шансы  
--    сразу по двум метрикам, т к здесь наименьшая конкуренция (в среднем 5,57 отклика на одну вакансию против почти 20 у аналитиков) 
--    и максимальная вероятность успеха (конверсия в приглашение 35,9%).
--
-- 3. Оговорка к выводу:
--    Эти данные показывают общую статистику, но они не учитывают качество 
--    конкретного резюме соискателя, его релевантность требованиям работодателя. 

-- ============================================================
-- БЛОК Е. Со звёздочкой
-- ============================================================

-- ЗАДАНИЕ Е1
-- Исходный запрос (выполнить и посмотреть результат):
SELECT v.professional_role,
       count(*) AS vacancies,
       sum(v.salary_from) AS total_salary,
       count(r.response_id) / count(*) AS responses_per_vacancy
FROM vacancies v
JOIN responses r ON v.vacancy_id = r.vacancy_id
WHERE v.closed_at = NULL
GROUP BY 1;

-- Результат: пустота.


-- Ошибки (минимум четыре):
-- 1. WHERE v.closed_at = NULL 
--    Сравнение с NULL через = всегда ложно, нужно использовать IS NULL. (из-за этого запрос возвращает пустой набор данных)
-- 2. JOIN с responses
--    Это убирает все вакансии, у которых нет ни одного отклика.
--    Для анализа нужно использовать LEFT JOIN, чтобы сохранить все вакансии.
-- 3. count(*) AS vacancies
--    После присоединения таблицы откликов одна вакансия повторяется в строках столько раз, сколько у неё откликов. 
--    count(*) посчитает общее число строк соединения, а не число уникальных вакансий. 
--    Тут надо использовать count(DISTINCT v.vacancy_id).
-- 4. count(r.response_id) / count(*)
--    Выражение выполняет целочисленное деление, теряя дробную часть.
--    Надо приводить к float (умножать на 1.0) и защищать знаменатель через nullif().


-- Исправленный запрос:
SELECT 
    v.professional_role,
    COUNT(DISTINCT v.vacancy_id) AS vacancies_cnt,
    (SELECT COALESCE(SUM(salary_from), 0) 
     FROM vacancies 
     WHERE professional_role = v.professional_role AND closed_at IS NULL) AS total_salary,  
    COUNT(r.response_id) AS responses_cnt,
    ROUND(1.0 * COUNT(r.response_id) / NULLIF(COUNT(DISTINCT v.vacancy_id), 0), 2) AS avg_responses_per_vacancy
FROM vacancies v
LEFT JOIN responses r ON v.vacancy_id = r.vacancy_id
WHERE v.closed_at IS NULL
GROUP BY v.professional_role;


-- Какие два правила из лекции защитили бы от этих ошибок при написании запроса:
-- 1. Правило NULL: пустоту проверяют только через IS NULL / IS NOT NULL. 
--    Сравнение с NULL даёт UNKNOWN и отсекает все строки.
-- 2. Правило JOIN один ко многим: после соединения дочерней таблицы строки родителя дублируются. 
--    Нельзя считать count(*) или sum() по полям родителя, для этого нужен LEFT JOIN (чтобы не терять объекты без связей), 
--    count(DISTINCT primary_key) для подсчёта уникальных объектов и nullif() в знаменателе любого отношения.
