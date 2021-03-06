# frozen_string_literal: true

class HTTPError < StandardError; end
class HTTPStatusNot200Error < HTTPError; end
class HTTP302FoundMovedError < HTTPError; end
class HTTP400BadRequestError < HTTPError; end
class HTTP401NotAuthorizedError < HTTPError; end
class HTTP403ForbiddenError < HTTPError; end
class HTTP404ResourceNotFoundError < HTTPError; end
class HTTP405MethodNotAllowedError < HTTPError; end
class HTTP413RequestEntitiyToLargeError < HTTPError; end
class HTTP424FailedDependencyError < HTTPError; end
class HTTP500InternalServerError < HTTPError; end
class HTTPMethodUnknownError < HTTPError; end
class TooManyRetriesError < StandardError; end
class FGTPortNotOpenError < StandardError; end
class SafeModeActiveError < StandardError; end
class CMDBPathError < StandardError; end
class CMDBNameError < StandardError; end
class CMDBMKeyError < StandardError; end
class CMDBChildNameError < StandardError; end
class CMDBChildMKeyError < StandardError; end
class NotAnIPError < StandardError; end
class FGTAddressTypeError < StandardError; end
class FGTVIPTypeError < StandardError; end
