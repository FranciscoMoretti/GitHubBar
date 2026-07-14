# GitHubBar

GitHubBar is a standalone native macOS menu-bar product for keeping high-volume GitHub work visible and actionable without repeatedly navigating GitHub's web interface.

## Language

**GitHubBar**:
The standalone product being designed in this repository; CodexBar is a design and architectural reference, not a host application or upstream codebase.
_Avoid_: CodexBar plugin, CodexBar feature

**Monitored account**:
The single authenticated GitHub account whose accessible repositories supply GitHubBar's pull-request workload. Organization and repository filters may mute parts of that workload.
_Avoid_: User, identity, profile

**Review request**:
An open pull request on which the monitored account or one of its teams currently has an explicit GitHub review request. Mere mentions, subscriptions, assignments, and past participation do not qualify.
_Avoid_: Notification, incoming PR, unread PR

**Authored pull request**:
An open pull request authored by the monitored account and tracked so GitHubBar can expose its next action and reviewer states.
_Avoid_: My PR, outgoing PR

**Next move**:
The party or condition currently preventing a pull request from progressing: the monitored account, a reviewer, required checks, or readiness to merge.
_Avoid_: Status, unread state, notification state

**Review roster**:
The people and teams associated with a pull request's review process, together with each one's current review state. An authored pull request with an empty review roster needs action from the monitored account.
_Avoid_: Reviewer list, assignees, participants

**Active workload**:
The monitored account's current review requests and authored pull requests, potentially spanning hundreds of pull requests under a target throughput of 100 pull requests per day.
_Avoid_: Inbox, feed, history
