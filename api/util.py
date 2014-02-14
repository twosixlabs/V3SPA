
class LazyModule(object):
  def __init__(self, name, loader, init_method=None):
    self.name = name
    self.loader = loader
    self.loaded = False
    self._init = init_method

  def __getattr__(self, attr):
    if self.loaded is False:
      self.__load__()
    return getattr(self.module, attr)

  def __load__(self):
    module = self.loader.find_module(self.name).load_module(self.name)
    if self._init is not None:
      self.module = getattr(module, self._init)()
    else:
      self.module = module

    self.loaded = True

