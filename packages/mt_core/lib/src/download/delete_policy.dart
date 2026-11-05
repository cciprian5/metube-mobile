/// What happens after a pull:
/// - [autoDelete] for Lite: delete from the server after pulling, so the
/// server cleans itself.
/// - [keepOnServer] for Super: it stays on the server, and deletion is
/// manual only.
enum DeletePolicy { autoDelete, keepOnServer }
