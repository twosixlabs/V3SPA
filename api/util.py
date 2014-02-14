
class LazyModule(object):
  def __init__(self, loader, init_method=None):
    self.loader = loader
    self.loaded = False
    self._init = init_method

  def __getattr__(self, attr):
    if self.loaded is False:
      self.__load__()
    return self.module.getattr(attr)

  def __load__(self):
    module = self.loader.load_module()
    if self._init is not None:
      self.module = getattr(module, self._init)()
    else:
      self.module = module

    self.loaded = True

