##
# Annotations are Submission and Problem specific.
# Currently, they are just text, but it would be nice if they could be used in
# score calculations in the future.
#
class Annotation < ApplicationRecord
  belongs_to :submission
  belongs_to :problem

  validates :comment, :filename, :submission_id, :problem_id, presence: true

  def as_text
    if value
      if problem
        "#{comment} (#{value}, #{problem.name})"
      else
        "#{comment} (#{value})"
      end
    elsif problem
      "#{comment} (#{problem.name})"
    else
      comment
    end
  end

  # Update all non-autograded scores with the following formula:
  # score_p = max_score_p + sum of annotations for problem
  def update_non_autograded_score
    # Get score for submission, or create one if it does not already exist
    # Previously, scores would be created when instructors add a score
    # and save on the gradebook
    score = Score.find_or_initialize_by_submission_id_and_problem_id(
      submission_id, problem_id
    )

    # Ensure that problem is non-autograded
    return if score.grader_id == 0

    # If score was newly-created, we need to add a grader_id to score
    if score.grader.nil?
      score.grader_id = CourseUserDatum.find_by(user_id: User.find_by(email: submitted_by).id,
                                                course_id: submission.assessment.course_id).id
    end

    # Obtain sum of all annotations for this score
    annotation_delta = Annotation
                       .where(submission_id: submission_id,
                              problem_id: problem_id)
                       .map(&:value).sum { |v| v.nil? ? 0 : v }

    # Default score to 0 if problem.max_score is nil
    max_score = score.problem.max_score || 0
    new_score = max_score + annotation_delta

    # Update score
    score.update!(score: new_score)
  end

  # This only applies when an annotation is for a group submission
  # Returns all annotations shared across one iteration of group submissions
  def group_associated_annotations
    raise "Annotation is not for a group submission!" if group_key.empty?

    Annotation.where(group_key: group_key).where.not(id: id)
  end
end
