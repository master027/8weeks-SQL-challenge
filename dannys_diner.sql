-- Case Study Questions

-- 1. What is the total amount each customer spent at the restaurant?

SELECT s.customer_id AS customer, SUM(m.price) AS total_spend
	FROM sales s
	JOIN menu m ON s.product_id = m.product_id
GROUP BY s.customer_id;

-- 2. How many days has each customer visited the restaurant?

SELECT customer_id, COUNT(DISTINCT order_date) AS count_days
	FROM sales
GROUP BY customer_id;

-- 3. What was the first item from the menu purchased by each customer?

WITH x AS 
(SELECT s.customer_id, m.product_name, 
		ROW_NUMBER() OVER(PARTITION BY s.customer_id ORDER BY order_date) AS row_num
FROM sales s
JOIN menu m ON s.product_id = m.product_id)

SELECT x.customer_id, x.product_name FROM x
WHERE x.row_num = 1;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT m.product_name, COUNT(*) AS no_of_orders
	FROM sales s
	JOIN menu m ON s.product_id = m.product_id
GROUP BY m.product_name
ORDER BY no_of_orders DESC
LIMIT 1;

-- 5. Which item was the most popular for each customer?

WITH x AS
(SELECT s.customer_id, m.product_name,
	COUNT(*) AS popular_item,
    RANK() OVER(PARTITION BY customer_id ORDER BY COUNT(*) DESC) AS rnk
FROM sales s
JOIN menu m ON s.product_id = m.product_id
GROUP BY s.customer_id, m.product_name)

SELECT x.customer_id, x.product_name
FROM x
WHERE rnk = 1 ;

-- 6. Which item was purchased first by the customer after they became a member?

WITH x AS 
(SELECT  s.customer_id, MIN(s.order_date) AS next_order_on FROM sales s
	JOIN 
members mb ON s.customer_id = mb.customer_id AND  s.order_date > mb.join_date
GROUP BY s.customer_id)

SELECT customer_id, product_name, order_date AS next_order_on FROM sales s
	JOIN menu m ON s.product_id = m.product_id
WHERE (customer_id, order_date) IN (SELECT x.customer_id, x.next_order_on FROM x)
ORDER BY customer_id;

-- 7. Which item was purchased just before the customer became a member?

WITH x AS 
(SELECT  s.customer_id, MAX(s.order_date) AS next_order FROM sales s
	JOIN 
members mb ON s.customer_id = mb.customer_id AND  s.order_date < mb.join_date
GROUP BY s.customer_id)

SELECT customer_id, product_name, order_date AS next_order FROM sales s
	JOIN menu m ON s.product_id = m.product_id
WHERE (customer_id, order_date) IN (SELECT x.customer_id, x.next_order FROM x)
ORDER BY customer_id;

-- 8. What is the total items and amount spent for each member before they became a member?

SELECT s.customer_id, COUNT(*) AS total_items, SUM(m.price) AS amount_spent 
  FROM sales s
	 JOIN 
    members mb ON s.customer_id = mb.customer_id AND s.order_date < mb.join_date
	 JOIN 
	menu m ON s.product_id = m.product_id
GROUP BY s.customer_id
ORDER BY s.customer_id;

/* 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - 
how many points would each customer have?
*/

SELECT s.customer_id,
	SUM(CASE
		WHEN m.product_name = 'sushi' THEN (m.price * 10 * 2)
        ELSE (m.price * 10)
		END) AS points
FROM sales s
JOIN menu m ON s.product_id = m.product_id
GROUP BY s.customer_id;

/*
10. In the first week after a customer joins the program (including their join date) 
they earn 2x points on all items, not just sushi 
- how many points do customer A and B have at the end of January?
*/

SELECT s.customer_id,
		SUM(
			CASE 
				WHEN s.order_date < DATE_ADD(mb.join_date, INTERVAL 7 DAY) THEN m.price * 10 * 2
				ELSE m.price * 10
			END) AS total_points
FROM sales s
	JOIN 
  members mb ON s.customer_id = mb.customer_id
	JOIN 
  menu m ON s.product_id = m.product_id
WHERE 
	s.order_date >= mb.join_date AND s.order_date < '2023-01-31'
GROUP BY s.customer_id
ORDER BY s.customer_id;


/*
** Bonus Questions - Join All The Things **

The following questions are related creating basic data tables that Danny and 
his team can use to quickly derive insights without needing to join the underlying tables using SQL.
*/

CREATE TABLE table_for_danny(
			customer_id VARCHAR(1),
			order_date DATE,
			product_name VARCHAR(10),
			price INTEGER,
			member ENUM('Y','N')
			);

-- INSERT INTO table_for_danny
SELECT s.customer_id, s.order_date, m.product_name, m.price,
	CASE
		WHEN s.customer_id IN (select customer_id from members) 
			AND order_date >= (select min(join_date) from members) THEN 'Y'
        ELSE 'N'
    END AS member
FROM sales s
LEFT JOIN members mb ON s.customer_id = mb.customer_id
JOIN menu m ON s.product_id = m.product_id
ORDER BY s.customer_id, s.order_date, m.product_name, m.price, member;

SELECT * FROM table_for_danny;

/*
** Rank All The Things **

Danny also requires further information about the ranking of customer products,
but he purposely does not need the ranking for non-member purchases
so he expects null ranking values for the records when customers are not yet part of the loyalty program.
*/

SELECT *,
	CASE
		WHEN customer_id IN (select customer_id from members) 
			AND order_date >= (select min(join_date) from members) 
		 THEN
            DENSE_RANK() OVER(PARTITION BY customer_id, member ORDER BY order_date)
	END AS ranking
FROM table_for_danny
ORDER BY customer_id, order_date;
