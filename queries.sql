-- =====================================================================
-- queries.sql
-- Consultas sobre o banco de dados de um museu
-- Pré-requisito: executar antes o arquivo schema.sql
-- Observação: LIMIT funciona em PostgreSQL/MySQL. No SQL Server use TOP,
-- no Oracle use FETCH FIRST n ROWS ONLY.
-- =====================================================================


-- =====================================================================
-- NÍVEL BÁSICO: SELECT, WHERE, ORDER BY
-- =====================================================================

-- 1. Obras criadas antes de 1950, da mais antiga para a mais recente
SELECT TITULO, ANO
FROM OBRAS
WHERE ANO < 1950
ORDER BY ANO;

-- 2. Funcionários com salário acima de 1000, do maior para o menor
SELECT NOME, FUNCAO, SALARIO
FROM FUNCIONARIOS
WHERE SALARIO > 1000
ORDER BY SALARIO DESC;

-- 3. Salões do 3º andar com área maior que 50 m²
SELECT NUMERO, ANDAR, AREA
FROM SALOES
WHERE ANDAR = 3
  AND AREA > 50;


-- =====================================================================
-- NÍVEL INTERMEDIÁRIO: JOIN, GROUP BY, HAVING
-- =====================================================================

-- 4. Obras com nome do autor e andar do salão (INNER JOIN em 3 tabelas)
SELECT O.TITULO,
       A.NOME   AS AUTOR,
       S.NUMERO AS SALAO,
       S.ANDAR
FROM OBRAS O
JOIN AUTORES A ON A.CODIGO = O.AUTOR
JOIN SALOES  S ON S.NUMERO = O.SALAO
ORDER BY S.ANDAR, O.TITULO;

-- 5. Autores que não têm nenhuma obra (LEFT JOIN + IS NULL)
-- Resultado esperado: AUTOR SEM OBRA
SELECT A.NOME
FROM AUTORES A
LEFT JOIN OBRAS O ON O.AUTOR = A.CODIGO
WHERE O.CODIGO IS NULL;

-- 6. Salões vazios, sem nenhuma obra exposta
-- Resultado esperado: salões 11 e 28
SELECT S.NUMERO, S.ANDAR
FROM SALOES S
LEFT JOIN OBRAS O ON O.SALAO = S.NUMERO
WHERE O.CODIGO IS NULL;

-- 7. Quantidade de obras por autor (inclui autores sem obra)
SELECT A.NOME,
       COUNT(O.CODIGO) AS QTD_OBRAS
FROM AUTORES A
LEFT JOIN OBRAS O ON O.AUTOR = A.CODIGO
GROUP BY A.NOME
ORDER BY QTD_OBRAS DESC;

-- 8. Autores com mais de 2 obras (HAVING)
-- Resultado esperado: SALVADOR DALI (4) e PABLO PICASSO (3)
SELECT A.NOME,
       COUNT(*) AS QTD_OBRAS
FROM AUTORES A
JOIN OBRAS O ON O.AUTOR = A.CODIGO
GROUP BY A.NOME
HAVING COUNT(*) > 2;

-- 9. Média salarial e quantidade de funcionários por turno
SELECT T.NOMETURNO,
       COUNT(*)        AS QTD,
       AVG(F.SALARIO)  AS MEDIA_SALARIAL
FROM FUNCIONARIOS F
JOIN TURNOS T ON T.CODTURNO = F.TURNO
GROUP BY T.NOMETURNO;

-- 10. Escultura mais pesada, com material, autor e salão
-- Resultado esperado: ESCULTURA DALI 2 (BRONZE, 600)
SELECT O.TITULO,
       E.MATERIAL,
       E.PESO,
       A.NOME AS AUTOR,
       O.SALAO
FROM ESCULTURAS E
JOIN OBRAS   O ON O.CODIGO = E.CODIGO
JOIN AUTORES A ON A.CODIGO = O.AUTOR
ORDER BY E.PESO DESC
LIMIT 1;

-- 11. Estilos de pintura de Salvador Dalí
SELECT O.TITULO,
       P.ESTILO,
       P.AREA
FROM PINTURAS P
JOIN OBRAS   O ON O.CODIGO = P.CODIGO
JOIN AUTORES A ON A.CODIGO = O.AUTOR
WHERE A.NOME = 'SALVADOR DALI';

-- 12. Total de obras por andar do museu (inclui andares sem obras)
SELECT S.ANDAR,
       COUNT(O.CODIGO) AS QTD_OBRAS
FROM SALOES S
LEFT JOIN OBRAS O ON O.SALAO = S.NUMERO
GROUP BY S.ANDAR
ORDER BY S.ANDAR;


-- =====================================================================
-- NÍVEL AVANÇADO: subconsultas, CASE, window functions, CTE, EXISTS
-- =====================================================================

-- 13. Funcionários com salário acima da média geral (subconsulta)
-- Resultado esperado: SEG2 e SEG4
SELECT NOME, FUNCAO, SALARIO
FROM FUNCIONARIOS
WHERE SALARIO > (SELECT AVG(SALARIO) FROM FUNCIONARIOS);

-- 14. Classificação das obras por período (CASE)
SELECT TITULO,
       ANO,
       CASE
         WHEN ANO < 1900 THEN 'Século XIX ou anterior'
         WHEN ANO < 1950 THEN 'Primeira metade do século XX'
         ELSE 'Segunda metade do século XX'
       END AS PERIODO
FROM OBRAS
ORDER BY ANO;

-- 15. Ranking salarial dentro de cada turno (window function)
SELECT NOME,
       TURNO,
       SALARIO,
       RANK() OVER (PARTITION BY TURNO ORDER BY SALARIO DESC) AS POSICAO
FROM FUNCIONARIOS;

-- 16. Obra mais antiga de cada autor (CTE + window function)
WITH RANKING AS (
  SELECT A.NOME AS AUTOR,
         O.TITULO,
         O.ANO,
         ROW_NUMBER() OVER (PARTITION BY A.CODIGO ORDER BY O.ANO) AS RN
  FROM OBRAS O
  JOIN AUTORES A ON A.CODIGO = O.AUTOR
)
SELECT AUTOR, TITULO, ANO
FROM RANKING
WHERE RN = 1;

-- 17. Funcionários alocados em mais de 2 salões diferentes
SELECT F.NOME,
       COUNT(DISTINCT AL.NUMERO) AS QTD_SALOES
FROM FUNCIONARIOS F
JOIN ALOCACOES AL ON AL.CPF = F.CPF
GROUP BY F.NOME
HAVING COUNT(DISTINCT AL.NUMERO) > 2;

-- 18. Pinturas com área acima da média das pinturas (subconsulta)
SELECT O.TITULO,
       P.ESTILO,
       P.AREA
FROM PINTURAS P
JOIN OBRAS O ON O.CODIGO = P.CODIGO
WHERE P.AREA > (SELECT AVG(AREA) FROM PINTURAS);

-- 19. Autores que têm pintura E escultura (EXISTS)
-- Resultado esperado: PINT E ESCULT BRASILEIRO e PINT E ESCULTOR FRANCES
SELECT A.NOME
FROM AUTORES A
WHERE EXISTS (SELECT 1
              FROM OBRAS O
              JOIN PINTURAS P ON P.CODIGO = O.CODIGO
              WHERE O.AUTOR = A.CODIGO)
  AND EXISTS (SELECT 1
              FROM OBRAS O
              JOIN ESCULTURAS E ON E.CODIGO = O.CODIGO
              WHERE O.AUTOR = A.CODIGO);

-- 20. Horas totais alocadas por funcionário
-- Observação: a coluna HORA_ENTRADA/HORA_SAIDA mistura os formatos '13:00' e '1300'.
-- REPLACE remove os dois pontos e SUBSTR pega os 2 primeiros dígitos (a hora).
-- Considera apenas horas cheias, pois todos os registros terminam em minuto 00.
SELECT F.NOME,
       SUM(
         CAST(SUBSTR(REPLACE(AL.HORA_SAIDA,   ':', ''), 1, 2) AS INTEGER) -
         CAST(SUBSTR(REPLACE(AL.HORA_ENTRADA, ':', ''), 1, 2) AS INTEGER)
       ) AS HORAS_TOTAIS
FROM FUNCIONARIOS F
JOIN ALOCACOES AL ON AL.CPF = F.CPF
GROUP BY F.NOME
ORDER BY HORAS_TOTAIS DESC;