enum Engine { fastai, openai }

extension EngineExt on Engine {
  String get label {
    switch (this) {
      case Engine.openai:
        return 'OpenAI';
      case Engine.fastai:
      default:
        return 'Default';
    }
  }
}
