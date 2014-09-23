CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  fname VARCHAR(255) NOT NULL,
  lname VARCHAR(255) NOT NULL
);

CREATE TABLE questions (
  id INTEGER PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  body TEXT NOT NULL,

  user_id INTEGER NOT NULL,

  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE question_followers (
  id INTEGER PRIMARY KEY,

  user_id INTEGER NOT NULL,
  question_id INTEGER NOT NULL,

  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (question_id) REFERENCES questions(id)
);

CREATE TABLE replies (
  id INTEGER PRIMARY KEY,
  body TEXT NOT NULL,

  question_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  reply_id INTEGER,

  FOREIGN KEY (question_id) REFERENCES questions(id),
  FOREIGN KEY (reply_id) REFERENCES replies(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE question_likes (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL,
  question_id INTEGER NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (question_id) REFERENCES questions(id)
);

--insert
INSERT INTO
  users(fname, lname)
VALUES
  ('kenny', 'G'),
  ('Senny', 'B'),
  ('Zenny', 'Y');

INSERT INTO
  questions(title, body, user_id)
VALUES
  ('pants','what are pants?', (SELECT id FROM users WHERE fname = 'Senny')),
   ('shirt','Does anyone have shirt?',
    (SELECT id FROM users WHERE fname = 'Senny')),
    ('bannanas','how many bannanas fit in a boat?',(SELECT id FROM users WHERE fname = 'Senny'));

INSERT INTO
  question_followers(question_id, user_id)
VALUES
  ((SELECT id FROM questions WHERE title = 'pants'),
  (SELECT id FROM users WHERE lname = 'Y')),

  ((SELECT id FROM questions WHERE title = 'pants'),
  (SELECT id FROM users WHERE lname = 'G')),

  ((SELECT id FROM questions WHERE title = 'pants'),
  (SELECT id FROM users WHERE lname = 'B')),

  ((SELECT id FROM questions WHERE title = 'shirt'),
  (SELECT id FROM users WHERE lname = 'Y'));

INSERT INTO
  replies(body,question_id,reply_id,user_id)
VALUES
  ('things for your legs to go in to',
    (SELECT id FROM questions WHERE title = 'pants'), NULL,
    (SELECT id FROM users WHERE fname = 'kenny') ),

    ('no there for your arms',
    (SELECT id FROM questions WHERE title = 'pants'), 1,
    (SELECT id FROM users WHERE fname = 'Senny'));


INSERT INTO
    question_likes (user_id, question_id)
VALUES
    (1,1),
    (2,1),
    (3,1),
    (3,2);


