require 'singleton'
require 'sqlite3'

class QuestionsDatabase < SQLite3::Database
  include Singleton

  def initialize
    super('questions.db')
    self.results_as_hash = true
    self.type_translation = true
  end

end

class User
  def self.all
    results = QuestionsDatabase.instance.execute('SELECT * FROM users')
    results.map { |result| User.new(result) }
  end

  attr_accessor :id, :fname, :lname
  def initialize(options = {})
    @id = options['id']
    @fname = options['fname']
    @lname = options['lname']
  end

  def create
    raise 'already saved!' unless self.id.nil?

    QuestionsDatabase.instance.execute(<<-SQL, fname, lname)
    INSERT INTO
      users(fname, lname)
    VALUES
      (?, ?)
    SQL

    @id = QuestionsDatabase.instance.last_insert_row_id
  end

  def self.find_by_id(target_id)
    result = QuestionsDatabase.instance.execute(<<-SQL, target_id)
    SELECT
      *
    FROM
      users
    WHERE
      id = (?)
    SQL
    User.new(result[0])
  end

  def self.find_by_name(target_fname, target_lname)
    result = QuestionsDatabase.instance.execute(<<-SQL, target_fname, target_lname)
    SELECT
      *
    FROM
      users
    WHERE
      fname = (?) AND lname = (?)
    SQL

    User.new(result[0])
  end

  def authored_questions
    Question.find_by_author_id(self.id)
  end

  def authored_replies
    Reply.find_by_author_id(self.id)
  end

  def followed_questions
    QuestionFollower.followed_questions_for_user_id(self.id)
  end

  def liked_questions
    QuestionLike::liked_questions_for_user_id(self.id)
  end

  def average_karma
    result = QuestionsDatabase.instance.execute(<<-SQL, self.id)
    SELECT
      CAST( COUNT(question_likes.id) AS FLOAT)/
      CAST( COUNT( DISTINCT(questions.id)) AS FLOAT)
    FROM
      questions LEFT OUTER JOIN question_likes
      ON questions.id = question_likes.question_id
    WHERE
      questions.user_id = (?)
    SQL
    result[0].values[0]
  end

  def save
    if @id.nil?
      self.create
    else
      QuestionsDatabase.instance.execute(<<-SQL, self.id, self.fname, self.lname, self.id)
        UPDATE
          users
        SET
          id = (?),
          fname = (?),
          lname = (?)
        WHERE
          id = (?)
        SQL
    end
  end

end


#---
class Question
  def self.all
    results = QuestionsDatabase.instance.execute('SELECT * FROM questions')
    results.map { |result| Question.new(result) }
  end

  attr_accessor :id, :title, :body, :user_id
  def initialize(options = {})
    @id = options['id']
    @title = options['title']
    @body = options['body']
    @user_id = options['user_id']
  end

  def create
    raise 'already saved!' unless self.id.nil?

    QuestionsDatabase.instance.execute(<<-SQL, title, body, user_id)
    INSERT INTO
      questions(title, body, user_id)
    VALUES
      (?, ?, ?)
    SQL

    @id = QuestionsDatabase.instance.last_insert_row_id
  end

  def self.find_by_id(target_id)
    result = QuestionsDatabase.instance.execute(<<-SQL, target_id)
    SELECT
      *
    FROM
      questions
    WHERE
      id = (?)
    SQL
    Question.new(result[0])
  end

  def self.find_by_title(target_title)
    results = QuestionsDatabase.instance.execute(<<-SQL, target_title)
    SELECT
      *
    FROM
      questions
    WHERE
      title = (?)
    SQL

    results.map { |result| Question.new(result) }
  end

  def self.find_by_author_id(author_id)
    results = QuestionsDatabase.instance.execute(<<-SQL, author_id)
    SELECT
      *
    FROM
      questions
    WHERE
      user_id = (?)
    SQL

    results.map { |result| Question.new(result) }
  end

  def author
    User.find_by_id(user_id)
  end

  def replies
    Reply.find_by_question_id(self.id)
  end

  def followers
    QuestionFollower.followers_for_question_id(self.id)
  end

  def self.most_followed(n)
    QuestionFollower::most_followed_questions(n)
  end

  def likers
    QuestionLike::likers_for_question_id(self.id)
  end

  def num_likes
    QuestionLike::num_likes_for_question_id(self.id)
  end

  def most_liked(n)
    QuestionLike.most_liked_questions(n)
  end

  def save
    if @id.nil?
      self.create
    else
      QuestionsDatabase.instance.execute(<<-SQL, id, title, body, user_id, self.id)
        UPDATE
          questions
        SET
          id = (?),
          title = (?),
          body = (?),
          user_id = (?)
        WHERE
          id = (?)
        SQL
    end
  end

end


class QuestionFollower
  def self.all
    results = QuestionsDatabase.instance.execute('SELECT * FROM question_followers')
    results.map { |result| QuestionFollower.new(result) }
  end

  attr_accessor :id, :user_id, :question_id
  def initialize(options = {})
    @id = options['id']
    @user_id = options['user_id']
    @question_id = options['question_id']
  end

  def create
    raise 'already saved!' unless self.id.nil?

    QuestionsDatabase.instance.execute(<<-SQL, user_id, question_id)
    INSERT INTO
      question_followers(user_id, question_id)
    VALUES
      (?, ?)
    SQL

    @id = QuestionsDatabase.instance.last_insert_row_id
  end

  def self.find_by_id(target_id)
    result = QuestionsDatabase.instance.execute(<<-SQL, target_id)
    SELECT
      *
    FROM
      question_followers
    WHERE
      id = (?)
    SQL
    QuestionFollower.new(result[0])
  end

  def self.followers_for_question_id(question_id)
    results = QuestionsDatabase.instance.execute(<<-SQL, question_id)
    SELECT
      users.id, fname, lname
    FROM
      question_followers AS q INNER JOIN users
      ON q.user_id = users.id
    WHERE
      q.question_id = (?)
    SQL
    results.map{|result| User.new(result)}
  end

  def self.followed_questions_for_user_id(user_id)
    results = QuestionsDatabase.instance.execute(<<-SQL, user_id)
    SELECT
      questions.id, title, body, questions.user_id
    FROM
      question_followers AS qf INNER JOIN questions
      ON qf.question_id = questions.id
    WHERE
      qf.user_id = (?)
    SQL
    results.map{|result| Question.new(result)}
  end

  def self.most_followed_questions(n)
    results = QuestionsDatabase.instance.execute(<<-SQL, n)
    SELECT
      questions.id, title, body, questions.user_id
    FROM
       questions LEFT OUTER JOIN question_followers AS qf
      ON qf.question_id = questions.id
    GROUP BY
      questions.id
    Order BY COUNT(*) DESC
    LIMIT (?)
    SQL
    results.map{|result| Question.new(result)}
  end

  def save
    if @id.nil?
      self.create
    else
      QuestionsDatabase.instance.execute(<<-SQL, id, user_id, question_id, self.id)
        UPDATE
          question_followers
        SET
          id = (?),
          user_id = (?),
          question_id = (?)
        WHERE
          id = (?)
        SQL
    end
  end

end

class Reply
  def self.all
    results = QuestionsDatabase.instance.execute('SELECT * FROM replies')
    results.map { |result| Reply.new(result) }
  end

  attr_accessor :id, :body, :question_id, :user_id, :reply_id
  def initialize(options = {})
    @id = options['id']
    @body = options['body']
    @question_id = options['question_id']
    @user_id = options['user_id']
    @reply_id = options['reply_id']
  end

  def create
    raise 'already saved!' unless self.id.nil?

    QuestionsDatabase.instance.execute(<<-SQL, body, question_id, user_id, reply_id)
    INSERT INTO
      replies(body, question_id, user_id, reply_id)
    VALUES
      (?, ?, ?, ?)
    SQL

    @id = QuestionsDatabase.instance.last_insert_row_id
  end

  def self.find_by_id(target_id)
    result = QuestionsDatabase.instance.execute(<<-SQL, target_id)
    SELECT
      *
    FROM
      replies
    WHERE
      id = (?)
    SQL

    return Reply.new(result[0]) unless result.empty?
    nil
  end

  def self.find_by_author_id(author_id)
    results = QuestionsDatabase.instance.execute(<<-SQL, author_id)
    SELECT
      *
    FROM
      replies
    WHERE
      user_id = (?)
    SQL

    results.map { |result| Reply.new(result) }
  end

  def self.find_by_question_id(question_id)
    results = QuestionsDatabase.instance.execute(<<-SQL, question_id)
    SELECT
      *
    FROM
      replies
    WHERE
      question_id = (?)
    SQL
    results.map { |result| Reply.new(result) }
  end

  def author
    User.find_by_id(user_id)
  end

  def question
    Question.find_by_id(question_id)
  end

  def parent_reply
    Reply.find_by_id(reply_id)
  end

  def child_replies
    results = QuestionsDatabase.instance.execute(<<-SQL, id)
    SELECT
      *
    FROM
      replies
    WHERE
      reply_id = (?)
    SQL

    results.map { |result| Reply.new(result) }
  end

  def save
    if @id.nil?
      self.create
    else
      QuestionsDatabase.instance.execute(<<-SQL, id, body, question_id, user_id, reply_id, self.id)
        UPDATE
          replies
        SET
          id = (?),
          body = (?),
          question_id = (?),
          user_id = (?),
          reply_id = (?)
        WHERE
          id = (?)
        SQL
    end
  end

end


class QuestionLike
  def self.all
    results = QuestionsDatabase.instance.execute('SELECT * FROM question_likes')
    results.map { |result| QuestionLike.new(result) }
  end

  attr_accessor :id, :user_id, :question_id
  def initialize(options = {})
    @id = options['id']
    @user_id = options['user_id']
    @question_id = options['question_id']
  end

  def create
    raise 'already saved!' unless self.id.nil?

    QuestionsDatabase.instance.execute(<<-SQL, user_id, question_id)
    INSERT INTO
      question_likes(user_id, question_id)
    VALUES
      (?, ?)
    SQL

    @id = QuestionsDatabase.instance.last_insert_row_id
  end

  def self.find_by_id(target_id)
    result = QuestionsDatabase.instance.execute(<<-SQL, target_id)
    SELECT
      *
    FROM
      question_likes
    WHERE
      id = (?)
    SQL
    QuestionLike.new(result[0])
  end

  def self.likers_for_question_id(question_id)
    results = QuestionsDatabase.instance.execute(<<-SQL, question_id)
    SELECT DISTINCT
      users.id, fname, lname
    FROM
      question_likes AS ql INNER JOIN users
      ON ql.user_id = users.id
    WHERE
      ql.question_id = (?)
    SQL
    results.map{|result| User.new(result)}
  end

  def self.num_likes_for_question_id(question_id)
    result = QuestionsDatabase.instance.execute(<<-SQL, question_id)
    SELECT
      COUNT(*)
    FROM
      question_likes AS ql INNER JOIN questions
      ON ql.question_id = questions.id
    WHERE
      ql.question_id = (?)
    SQL
    result[0].values[0]
  end

  def self.liked_questions_for_user_id(user_id)
      results = QuestionsDatabase.instance.execute(<<-SQL, user_id)
      SELECT
        questions.id, title, body, questions.user_id
      FROM
        question_likes AS ql INNER JOIN questions
        ON ql.question_id = questions.id
      WHERE
        ql.user_id = (?)
      SQL
      results.map{|result| Question.new(result)}
  end

  def self.most_liked_questions(n)
    results = QuestionsDatabase.instance.execute(<<-SQL, n)
    SELECT
      questions.id, title, body, questions.user_id
    FROM
       questions LEFT OUTER JOIN question_likes AS ql
      ON ql.question_id = questions.id
    GROUP BY
      questions.id
    Order BY COUNT(*) DESC
    LIMIT (?)
    SQL
    results.map{|result| Question.new(result)}
  end


end

