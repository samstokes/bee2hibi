module JiraToHibi
  class Client
    def initialize(opts = {})
      @hibi = opts.fetch :hibi
      @jira = opts.fetch :jira
      @jira_user = @jira.user
    end

    def sync(sprint)
      sprint_issues = get_sprint_issues(sprint)

      sync_issues_to_hibi(sprint_issues)

      active_issue_tasks = get_active_issue_tasks

      update_existing_hibi_tasks(active_issue_tasks, sprint_issues)
    end

    private
    def get_sprint_issues(sprint)
      puts "Getting issues for sprint #{sprint}"

      @jira.my_issues(sprint).tap do |issues|
        puts "Got #{issues.size} issues from Jira: #{issues.map(&:key).join(', ')}"
      end
    end

    def get_active_issue_tasks
      hibi_jira_tasks = @hibi.my_ext_tasks('jira')

      hibi_jira_tasks.select(&:ext_active?).tap do |active|
        puts "Got #{hibi_jira_tasks.size} issues from Hibi, #{active.size} active: #{active.map(&:ext_id).join(', ')}"
      end
    end

    def sync_issues_to_hibi(issues)
      errors = []
      issues.each do |issue|
        begin
          @hibi.create_or_update_task(jira_issue_to_hibi_task(issue))
        rescue => e
          puts "Failed to update issue #{issue.key} (#{issue.summary}) to Hibi!\n#{e}"
          errors << e
        end
      end
      puts "Synced #{issues.size - errors.size} of my issues to Hibi, #{errors.size} errors."
    end

    def update_existing_hibi_tasks(tasks, already_synced_issues)
      yet_unsynced_keys = tasks.map(&:ext_id) - already_synced_issues.map(&:key)
      puts "#{yet_unsynced_keys.size} need syncing: #{yet_unsynced_keys.join(', ')}"

      errors = []
      yet_unsynced_keys.each do |key|
        begin
          issue = @jira.issue(key)
          @hibi.create_or_update_task(jira_issue_to_hibi_task(issue))
        rescue => e
          puts "Failed to sync issue #{key} (#{issue.summary if issue}) to Hibi!\n#{e}"
          errors << e
        end
      end
      puts "Synced #{yet_unsynced_keys.size} issues from Jira, #{errors.size} errors."
    end

    def jira_issue_to_hibi_task(issue)
      assignee = case issue.assignee
                when nil, 'None'
                  'not assigned'
                when @jira_user
                  nil
                else
                  issue.assignee
                end
      Hibi::Task.new(
        ext_id: issue.key,
        title: issue.summary,
        schedule: 'Once',
        ext_source: 'jira',
        ext_url: issue.web_url,
        ext_status: issue.status,
        ext_assignee: assignee,
      )
    end
  end
end
