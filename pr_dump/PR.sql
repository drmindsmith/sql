/*This whole sequence is run in MYSQL, so some commands or formats might not work in another program. The info is not delimited (?) so the columns are in quotes and often contain whitespace.

Part one: check the data*/

SELECT *
FROM pr1
LIMIT 1;

/* look at the students Bess reviewed*/

SELECT *
FROM pr1
WHERE `Rev 1` = 'Bess';

/* which of Bess' students are at risk of disqualification*/

WITH bess_rev AS (
	SELECT *
	FROM pr1
	WHERE `Rev 1` = 'Bess' AND `Current Acad Stndng Stat` = 'Subject to Dismissal')
SELECT `Person ID`, `Cumulative GPA`, `Term GPA`, `B Deficit`, `Previous Term B Deficit`
FROM bess_rev;

/* that's too much - lets look at which made their situation worse this semester*/

WITH bess_rev AS (
	SELECT *
	FROM pr1
	WHERE `Rev 1` = 'Bess' AND `Current Acad Stndng Stat` = 'Subject to Dismissal')
SELECT `Person ID`, `Cumulative GPA`, `Term GPA`, `B Deficit`, `Previous Term B Deficit`, (`Previous Term B Deficit` - `B Deficit`)
FROM bess_rev
WHERE (`Previous Term B Deficit` - `B Deficit`) < 0 ;

/* but wait, maybe they are replacing a course and it's messing with the data*/

WITH bess_rev AS (
	SELECT *
	FROM pr1
	WHERE `Rev 1` = 'Bess' AND `Current Acad Stndng Stat` = 'Subject to Dismissal')
SELECT `Person ID`, `Cumulative GPA`, `Term GPA`, `B Deficit`, `Previous Term B Deficit`, (`Previous Term B Deficit` - `B Deficit`), `GRO Flag`
FROM bess_rev
WHERE (`Previous Term B Deficit` - `B Deficit`) > 0 AND `GRO Flag` = 'Y';

/* so these three need special consideration and a deeper dive - take note of them. back to the data (writ large)

`Person ID` is terrible - that's the primary key for the whole thing and is necessary for future - let's edit that column so it's easier to work with*/

ALTER TABLE pr1 CHANGE `Person ID` id int;

ALTER TABLE pr1 ADD primary key(id);

/* Fixing the this should make referencing the student (specifically) easier and less time-consuming. But, this throws a duplicate error - lets hunt that down*/

SELECT *
FROM pr1
WHERE id=23260924;

/* that reveals the student is actually a double-major - same kid, two rows. Keep track because she's getting an intitial evaluation by two people and if they disagree it requires attention

let's automate some analysis - if the student was NOT on probation last semester (had a B-Deficit of 0 or better) they get this semester to screw up and are JUST on probation. Let's identify if those students are accurately coded.*/

SELECT id, `Current Acad Stndng Stat`, `Previous Term B Deficit`, `GRO Flag`
FROM pr1
ORDER BY 2;

/* there's some weird stuff in there - let's look deeper with more clarity:
Current Academic Standing is Subject to Dismissal if the student has NOT improved their probation status. Unless they are replacing an old grade (GRO), their b-deficit must improve from semester to semester. We looked at 'improve' with (`Previous Term B Deficit` - `B Deficit`) > 0 above, so let's compare it to the status recommedation*/

SELECT id, `Current Acad Stndng Stat`, `B Deficit`, `Previous Term B Deficit`, (`Previous Term B Deficit` - `B Deficit`) improve, `GRO Flag`
FROM pr1
WHERE (`Previous Term B Deficit` - `B Deficit`) > 0
ORDER BY 2;

/* ID 00546201 looks to be dismissed - old number implies an old student, but that one improved from 0 to -6. Aside from that student, everyone on this list looks to have improved their situation (without the depth of the GRO option) and should be retained.

Now let's look at the other side of the equation - who made their situation worse?*/

SELECT id, `Current Acad Stndng Stat`, `B Deficit`, `Previous Term B Deficit`, (`Previous Term B Deficit` - `B Deficit`) improve, `GRO Flag`
FROM pr1
WHERE (`Previous Term B Deficit` - `B Deficit`) <= 0
ORDER BY 4;

/* That's too much -let's look at the zero-change kids*/

SELECT id, `Current Acad Stndng Stat`, `B Deficit`, `Previous Term B Deficit`, (`Previous Term B Deficit` - `B Deficit`) improve, `GRO Flag`
WHERE (`Previous Term B Deficit` - `B Deficit`) = 0
ORDER BY 4;
FROM pr1

/* According to policy, each of these kids should be expelled - the GRO might make a difference, so...*/

WITH no_change AS (
	SELECT id, `Current Acad Stndng Stat`, `B Deficit`, `Previous Term B Deficit`, (`Previous Term B Deficit` - `B Deficit`) improve, `GRO Flag`
	FROM pr1
	WHERE (`Previous Term B Deficit` - `B Deficit`) = 0
	ORDER BY 4)
SELECT id
FROM no_change
WHERE `GRO Flag` = 'Y';

/* these 15 students need a deeper dive before expulsion

ok, so the batch went to advisors to review - let's look at who was recommended for dismissal after the first round (this is a new table)*/

SELECT *
FROM pr2
WHERE `Action 1` = 'UDQ'

/* That's 128 students who are recommended for the univeristy boot. I wonder if anyone is being harsh...*/

SELECT `Rev 1`, COUNT(*)
FROM pr2
GROUP BY 1;

/* what? Bess had 151 reviews and no one else was above 80?*/

SELECT `Rev 1`, COUNT(*)
FROM pr1
GROUP BY 1;

/* Oh - Keely was absent and Bess was fast - I remember now. Bess just did Keely's assignment too*/

SELECT `Rev 1`, `Action 1`, COUNT(*)
FROM pr2
WHERE `Action 1`= 'UDQ'
GROUP BY 1, 2
ORDER BY 1;

/* Hmm, if Bess really did 151 reviews and only recommended 22 disqualifications, she's not harsh. Let's compare everyone:

NOTE: I didn't actually use the first view in my analysis - I was struggling to get MYSQL to recognize the tables and columns with the whitespace in the labels*/

  CREATE VIEW review_total
  AS
  SELECT `Rev 1` rev_1, `Action 1` r1_action, COUNT(*) rev_count
  FROM pr2
  GROUP BY 1, 2)

/* but I did use this view*/

CREATE VIEW dq_total
AS
SELECT `Rev 1` dq_1, `Action 1` dq_action, COUNT(*) dq_count
FROM pr2
WHERE `Action 1` = 'UDQ'
GROUP BY 1, 2

WITH review_total AS (
	SELECT `Rev 1` rev_1, `Action 1` r1_action, COUNT(*) rev_count
	FROM pr2
	GROUP BY 1)
SELECT rev_1, dq_count, rev_count, dq_count/rev_count ratio
FROM review_total
JOIN dq_total
ON dq_1=rev_1

/* So, the range is .146 - .4211, with most in the 20's and the .4211 was my boss so she was a little less liberal with her reviews. It would be interesting to see if this is a statistically interesting range, or if Bess and Leticia are outliers. Also, it'd be good to see if these numbers are consistent from semester to semester. In either case (and probably the former case above), the work would be easier in Python.

Ideally , I'd continue and look at more and more-interesting results, try to create a dashboard (eventually) that helps the boss understand the numbers and predictions from what happened and may happen, and include the additional table wherein we were looking at students from other colleges.*/
